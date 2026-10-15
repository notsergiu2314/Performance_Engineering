/*Crown Copyright 2012 AWE.
*
* This file is part of CloverLeaf.
*
* CloverLeaf is free software: you can redistribute it and/or modify it under
* the terms of the GNU General Public License as published by the
* Free Software Foundation, either version 3 of the License, or (at your option)
* any later version.
*
* CloverLeaf is distributed in the hope that it will be useful, but
* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
* details.
*
* You should have received a copy of the GNU General Public License along with
* CloverLeaf. If not, see http://www.gnu.org/licenses/. */

/**
 *  @brief C timestep kernel
 *  @author Wayne Gaudin
 *  @details calculates the minimum timestep on the mesh chunk based on the CFL
 *  condition, the velocity gradient and the velocity divergence. A safety
 *  factor is used to ensure numerical stability.
 *
 *  M3 restructuring (report, "Byte reductions" (5) and time-only change T2).
 *  The original kernel stored the local timestep of every cell to the scratch
 *  array dt_min (work_array1) in one loop and reduced that array to a scalar
 *  in a second loop: one full-mesh store plus its read-for-ownership, and one
 *  full-mesh reload, for a value that is only ever min-reduced. The reduction
 *  now happens inside the first loop and dt_min is no longer touched (the
 *  argument is kept so the Fortran interface is unchanged).
 *
 *  Which cell and which criterion set the minimum is only needed in the
 *  failure message when the step drops below dtmin. Instead of tracking the
 *  location in the hot loop (an argmin, which does not vectorise cleanly),
 *  the kernel re-evaluates the per-cell criterion in a serial scan when, and
 *  only when, that failure occurs. The Fortran port of this kernel used
 *  MINLOC; the previous C port returned placeholders (cell (1,1), control 1).
 *
 *  T2: sqrt() in the hot loop only vectorises with -fno-math-errno (set in the
 *  Makefile for GNU and ARM); with errno semantics GCC keeps a scalar call.
 */

#include <stdio.h>
#include <stdlib.h>
#include "ftocmacros.h"
#include "papi_prof.h"
#include <math.h>

#define IDXN(j,k) FTNREF2D((j),(k),x_max+5,x_min-2,y_min-2)   /* node / face arrays */
#define IDXC(j,k) FTNREF2D((j),(k),x_max+4,x_min-2,y_min-2)   /* cell-centred arrays */

/* Criterion numbers reported through dtl_control (calc_dt.f90 maps them to
 * the words printed in the step log). */
enum { CTRL_SOUND=1, CTRL_XVEL=2, CTRL_YVEL=3, CTRL_DIV=4 };

/* The four timestep limits of one cell. Shared by the hot loop (which keeps
 * only their minimum) and by the diagnostic scan on failure (which also needs
 * to know which one was binding). always_inline so the simd loop sees plain
 * arithmetic, not a call. */
static inline __attribute__((always_inline))
void cell_dt_limits(int j,int k,int x_min,int x_max,int y_min,int y_max,
                    double g_small,double g_big,
                    double dtc_safe,double dtu_safe,double dtv_safe,double dtdiv_safe,
                    const double *xarea,const double *yarea,
                    const double *celldx,const double *celldy,
                    const double *volume,const double *density0,
                    const double *viscosity,const double *soundspeed,
                    const double *xvel0,const double *yvel0,
                    double *dtct,double *dtut,double *dtvt,double *dtdivt)
{
  double dsx,dsy,cc,dv1,dv2,div;
  const double vol=volume[IDXC(j,k)];

  /* Cell widths in x and y. */
  dsx=celldx[FTNREF1D(j,x_min-2)];
  dsy=celldy[FTNREF1D(k,y_min-2)];

  /* (1) CFL / sound-speed limit.
   * Effective sound speed squared = c^2 + 2*q/rho, where the artificial
   * viscosity q acts as extra stiffness. Clamp to g_small to avoid a
   * division by zero in a quiescent cell. */
  cc=soundspeed[IDXC(j,k)]*soundspeed[IDXC(j,k)];
  cc=cc+2.0*viscosity[IDXC(j,k)]/density0[IDXC(j,k)];
  cc=MAX(sqrt(cc),g_small);

  *dtct=dtc_safe*MIN(dsx,dsy)/cc;        /* time for sound to cross the cell */

  /* div accumulates the net volume flux out of the cell (all four faces). */
  div=0.0;

  /* (2) x-velocity limit.
   * dv1/dv2 = volume flux through the left (j) and right (j+1) faces:
   * sum of the two face-node velocities times the face area. */
  dv1=(xvel0[IDXN(j  ,k)]+xvel0[IDXN(j  ,k+1)])*xarea[IDXN(j  ,k)];
  dv2=(xvel0[IDXN(j+1,k)]+xvel0[IDXN(j+1,k+1)])*xarea[IDXN(j+1,k)];

  div=div+dv2-dv1;                        /* net outflow in x */

  /* Time until the cell has been swept by its own volume through the
   * fastest x face. Denominator is clamped so an almost-still cell does
   * not blow up. */
  *dtut=dtu_safe*2.0*vol/MAX(fabs(dv1),MAX(fabs(dv2),g_small*vol));

  /* (3) y-velocity limit, same construction for bottom (k) / top (k+1). */
  dv1=(yvel0[IDXN(j,k  )]+yvel0[IDXN(j+1,k  )])*yarea[IDXC(j,k  )];
  dv2=(yvel0[IDXN(j,k+1)]+yvel0[IDXN(j+1,k+1)])*yarea[IDXC(j,k+1)];

  div=div+dv2-dv1;                        /* net outflow in y */

  *dtvt=dtv_safe*2.0*vol/MAX(fabs(dv1),MAX(fabs(dv2),g_small*vol));

  /* (4) divergence limit.
   * Normalise to a rate of relative volume change (1/time). A negative
   * value means the cell is being compressed; -1/div is the time until
   * it would collapse to zero volume. An expanding cell imposes no limit. */
  div=div/(2.0*vol);

  if(div < -g_small) {
    *dtdivt=dtdiv_safe*(-1.0/div);
  }
  else {
    *dtdivt=g_big;
  }
}

void calc_dt_kernel_c_(int *xmin,int *xmax,int *ymin,int *ymax,
                    double *gsmall,double *gbig,double *mindt,
                    double *dtcsafe,
                    double *dtusafe,
                    double *dtvsafe,
                    double *dtdivsafe,
                    double *xarea,
                    double *yarea,
                    double *cellx,
                    double *celly,
                    double *celldx,
                    double *celldy,
                    double *volume,
                    double *density0,
                    double *energy0,
                    double *pressure,
                    double *viscosity,
                    double *soundspeed,
                    double *xvel0,
                    double *yvel0,
                    double *dt_min,     /* unused since M3-5; kept for the Fortran interface */
                    double *dtminval,   /* OUT: minimum timestep over the whole tile */
                    int *dtlcontrol,    /* OUT: binding criterion, see enum above */
                    double *xlpos,
                    double *ylpos,
                    int *jldt,
                    int *kldt,
                    int *smll)
{

  int  x_min=*xmin;
  int  x_max=*xmax;
  int  y_min=*ymin;
  int  y_max=*ymax;

  double g_small=*gsmall;
  double g_big=*gbig;
  double dt_min_val;
  double dtc_safe=*dtcsafe;
  double dtu_safe=*dtusafe;
  double dtv_safe=*dtvsafe;
  double dtdiv_safe=*dtdivsafe;
  double min_dt=*mindt;

  int dtl_control=CTRL_SOUND;
  double xl_pos=0.0;
  double yl_pos=0.0;
  int j_ldt=1;
  int k_ldt=1;
  int small=0;

  int j,k;
  double dtct,dtut,dtvt,dtdivt;

  (void)dt_min;   /* no longer written, see header */

  /* Start from a huge value; every cell can only lower it. */
  dt_min_val = g_big;

  /*
   * Single pass: evaluate the four limits per cell and min-reduce on the fly.
   * reduction(min:) on both the worksharing loop and the simd loop gives each
   * thread (and each vector lane) a private running minimum that OpenMP
   * combines at the end. min is exact, so the result does not depend on the
   * order in which the partial minima are combined.
   */
#pragma omp parallel
 {
  PROF_BEGIN(PROF_CALC_DT);

#pragma omp for private(j,dtct,dtut,dtvt,dtdivt) reduction(min:dt_min_val)
  for (k=y_min;k<=y_max;k++) {
#pragma omp simd private(dtct,dtut,dtvt,dtdivt) reduction(min:dt_min_val)
    for (j=x_min;j<=x_max;j++) {
      cell_dt_limits(j,k,x_min,x_max,y_min,y_max,g_small,g_big,
                     dtc_safe,dtu_safe,dtv_safe,dtdiv_safe,
                     xarea,yarea,celldx,celldy,volume,density0,
                     viscosity,soundspeed,xvel0,yvel0,
                     &dtct,&dtut,&dtvt,&dtdivt);
      /* The binding constraint for this cell is the smallest of the four. */
      dt_min_val = MIN(dt_min_val,MIN(dtct,MIN(dtut,MIN(dtvt,dtdivt))));
    }
  }

  PROF_END(PROF_CALC_DT);
 }

  /* min_dt is the user-specified floor (dtmin in the input deck). Dropping
   * below it means the simulation has gone unstable; flag it so the driver
   * can print diagnostics and abort. */
  if(dt_min_val < min_dt) small=1;

  if(small != 0) {
    /* Failure path only: locate the cell that produced dt_min_val and which
     * of the four limits it was. Serial, runs once, then the code aborts. */
    for (k=y_min;k<=y_max;k++) {
      for (j=x_min;j<=x_max;j++) {
        cell_dt_limits(j,k,x_min,x_max,y_min,y_max,g_small,g_big,
                       dtc_safe,dtu_safe,dtv_safe,dtdiv_safe,
                       xarea,yarea,celldx,celldy,volume,density0,
                       viscosity,soundspeed,xvel0,yvel0,
                       &dtct,&dtut,&dtvt,&dtdivt);
        if(MIN(dtct,MIN(dtut,MIN(dtvt,dtdivt))) == dt_min_val) {
          j_ldt=j;
          k_ldt=k;
          if     (dtct   == dt_min_val) dtl_control=CTRL_SOUND;
          else if(dtut   == dt_min_val) dtl_control=CTRL_XVEL;
          else if(dtvt   == dt_min_val) dtl_control=CTRL_YVEL;
          else                          dtl_control=CTRL_DIV;
          xl_pos=cellx[FTNREF1D(j_ldt,x_min-2)];
          yl_pos=celly[FTNREF1D(k_ldt,y_min-2)];
          goto found;
        }
      }
    }
    found:;
  }

  *dtminval=dt_min_val;
  *dtlcontrol=dtl_control;
  *xlpos=xl_pos;
  *ylpos=yl_pos;
  *jldt=j_ldt;
  *kldt=k_ldt;

  /* Diagnostic dump of the limiting cell when dt is too small. */
  if(small != 0) {
    printf("Timestep information:\n");
    printf("j, k                 :%i %i \n",j_ldt,k_ldt);
    printf("x, y                 :%f %f \n",xl_pos,yl_pos);
    printf("timestep : %f\n",dt_min_val);
    printf("Cell velocities;\n");
    printf("%f %f \n",xvel0[IDXN(j_ldt  ,k_ldt  )],yvel0[IDXN(j_ldt  ,k_ldt  )]);
    printf("%f %f \n",xvel0[IDXN(j_ldt+1,k_ldt  )],yvel0[IDXN(j_ldt+1,k_ldt  )]);
    printf("%f %f \n",xvel0[IDXN(j_ldt+1,k_ldt+1)],yvel0[IDXN(j_ldt+1,k_ldt+1)]);
    printf("%f %f \n",xvel0[IDXN(j_ldt  ,k_ldt+1)],yvel0[IDXN(j_ldt  ,k_ldt+1)]);
    printf("density, energy, pressure, soundspeed \n");
    printf("%f %f %f %f \n",density0[IDXC(j_ldt,k_ldt)],energy0[IDXC(j_ldt,k_ldt)],pressure[IDXC(j_ldt,k_ldt)],soundspeed[IDXC(j_ldt,k_ldt)]);
  }

}
