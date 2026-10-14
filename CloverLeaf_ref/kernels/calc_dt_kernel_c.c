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
 */

#include <stdio.h>
#include <stdlib.h>
#include "ftocmacros.h"
#include "papi_prof.h"
#include <math.h>

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
                    double *dt_min,     /* scratch array (work_array1 in Fortran): per-cell timestep limit */
                    double *dtminval,   /* OUT: minimum timestep over the whole tile */
                    int *dtlcontrol,
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
  double dt_min_val=*dtminval;
  double dtc_safe=*dtcsafe;
  double dtu_safe=*dtusafe;
  double dtv_safe=*dtvsafe;
  double dtdiv_safe=*dtdivsafe;
  double min_dt=*mindt;

  int dtl_control=*dtlcontrol;
  double xl_pos=*xlpos;
  double yl_pos=*ylpos;
  int j_ldt=*jldt;
  int k_ldt=*kldt;
  int small=*smll;

  int j,k;

  double div,dsx,dsy,dtut,dtvt,dtct,dtdivt,cc,dv1,dv2,jk_control;

  small=0;

  /* Start from a huge value; every cell can only lower it. */
  dt_min_val = g_big;
  jk_control=1.1;

  /*
   * Pass 1: for every cell compute four candidate timestep limits and store
   * the smallest in dt_min(j,k). Each cell writes only its own entry, so the
   * loop is fully parallel and vectorisable.
   *
   * Field sizes (Fortran layout, j fastest):
   *   cell-centred  (x_max+4 per row): soundspeed, viscosity, density0, volume
   *   node/face     (x_max+5 per row): xvel0, yvel0, xarea, dt_min
   *   yarea is cell-sized in x (x_max+4 per row) but has an extra row in y.
   */

#pragma omp parallel
 {
  PROF_BEGIN(PROF_CALC_DT);

  /* TODO(M3-5): fuse the reduction into this loop: add reduction(min:dt_min_val) here,
   * accumulate dt_min_val = MIN(dt_min_val, ...) instead of storing to dt_min, and delete
   * pass 2. Saves a full-mesh store + reload. (-1.1%) */
  /* TODO(M3-T2): sqrt below keeps this loop scalar (0% NEON); build with -fno-math-errno. */
#pragma omp for private(dsx,dsy,cc,dv1,dv2,div,dtct,dtut,dtvt,dtdivt,j,k)
  for (k=y_min;k<=y_max;k++) {
#pragma omp simd
    for (j=x_min;j<=x_max;j++) {

       /* Cell widths in x and y. */
       dsx=celldx[FTNREF1D(j,x_min-2)];
       dsy=celldy[FTNREF1D(k,y_min-2)];

       /* (1) CFL / sound-speed limit.
        * Effective sound speed squared = c^2 + 2*q/rho, where the artificial
        * viscosity q acts as extra stiffness. Clamp to g_small to avoid a
        * division by zero in a quiescent cell. */
       cc=soundspeed[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)]*soundspeed[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)];
       cc=cc+2.0*viscosity[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)]/density0[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)];
       cc=MAX(sqrt(cc),g_small);

       dtct=dtc_safe*MIN(dsx,dsy)/cc;     /* time for sound to cross the cell */

       /* div accumulates the net volume flux out of the cell (all four faces). */
       div=0.0;

       /* (2) x-velocity limit.
        * dv1/dv2 = volume flux through the left (j) and right (j+1) faces:
        * sum of the two face-node velocities times the face area. */
       dv1=(xvel0[FTNREF2D(j  ,k  ,x_max+5,x_min-2,y_min-2)]+xvel0[FTNREF2D(j  ,k+1,x_max+5,x_min-2,y_min-2)])*xarea[FTNREF2D(j  ,k  ,x_max+5,x_min-2,y_min-2)];
       dv2=(xvel0[FTNREF2D(j+1,k  ,x_max+5,x_min-2,y_min-2)]+xvel0[FTNREF2D(j+1,k+1,x_max+5,x_min-2,y_min-2)])*xarea[FTNREF2D(j+1,k  ,x_max+5,x_min-2,y_min-2)];

       div=div+dv2-dv1;                   /* net outflow in x */

       /* Time until the cell has been swept by its own volume through the
        * fastest x face. Denominator is clamped so an almost-still cell does
        * not blow up. */
       dtut=dtu_safe*2.0*volume[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)]/MAX(fabs(dv1),MAX(fabs(dv2),g_small*volume[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)]));

       /* (3) y-velocity limit, same construction for bottom (k) / top (k+1). */
       dv1=(yvel0[FTNREF2D(j,k,x_max+5,x_min-2,y_min-2)]+yvel0[FTNREF2D(j+1,k,x_max+5,x_min-2,y_min-2)])*yarea[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)];
       dv2=(yvel0[FTNREF2D(j,k+1,x_max+5,x_min-2,y_min-2)]+yvel0[FTNREF2D(j+1,k+1,x_max+5,x_min-2,y_min-2)])*yarea[FTNREF2D(j,k+1,x_max+4,x_min-2,y_min-2)];

       div=div+dv2-dv1;                   /* net outflow in y */

       dtvt=dtv_safe*2.0*volume[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)]/MAX(fabs(dv1),MAX(fabs(dv2),g_small*volume[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)]));

       /* (4) divergence limit.
        * Normalise to a rate of relative volume change (1/time). A negative
        * value means the cell is being compressed; -1/div is the time until
        * it would collapse to zero volume. An expanding cell imposes no limit. */
       div=div/(2.0*volume[FTNREF2D(j,k,x_max+4,x_min-2,y_min-2)]);

       if(div < -g_small) {
         dtdivt=dtdiv_safe*(-1.0/div);
       }
       else {
         dtdivt=g_big;
       }

       /* The binding constraint for this cell is the smallest of the four. */
       dt_min[FTNREF2D(j,k,x_max+5,x_min-2,y_min-2)] = MIN(dtct,MIN(dtut,MIN(dtvt,dtdivt)));

    }
  }

  /*
   * Pass 2: reduce the per-cell array to a single scalar. dt_min is never
   * read again after this; it exists only to separate the vectorisable
   * arithmetic above from the min-reduction. (The two passes could be fused
   * into one loop with reduction(min:dt_min_val), saving a full-mesh store
   * and reload.)
   */
  /* TODO(M3-5): delete this pass once the reduction is fused into pass 1. */
#pragma omp for private(j) reduction(min:dt_min_val)
  for (k=y_min;k<=y_max;k++) {
#pragma omp simd
    for (j=x_min;j<=x_max;j++) {
      if(dt_min[FTNREF2D(j,k,x_max+5,x_min-2,y_min-2)] < dt_min_val) dt_min_val=dt_min[FTNREF2D(j,k,x_max+5,x_min-2,y_min-2)];
    }
  }

  PROF_END(PROF_CALC_DT);
 }

  /*
   * Extract the minimum timestep information.
   *
   * The Fortran kernel uses MINLOC to report which cell (j_ldt,k_ldt) and
   * which of the four limits (dtl_control: 1=sound, 2=xvel, 3=yvel, 4=div)
   * was binding. This C port never implemented that: jk_control is a fixed
   * 1.1, the location is forced to (1,1) and dtl_control is always returned
   * as 1 ("sound"). The values printed below are therefore placeholders.
   */
  dtl_control=10.01*(jk_control-(int)(jk_control));
  jk_control=jk_control-(jk_control-(int)(jk_control));
  j_ldt=1; //MOD(INT(jk_control),x_max)
  k_ldt=1; //1+(jk_control/x_max)
  //xl_pos=cellx[FTNREF1D(j_ldt,xmin-2)];
  //yl_pos=celly[FTNREF1D(j_ldt,ymin-2)];

  /* min_dt is the user-specified floor (dtmin in the input deck). Dropping
   * below it means the simulation has gone unstable; flag it so the driver
   * can print diagnostics and abort. */
  if(dt_min_val < min_dt) small=1;

  *dtminval=dt_min_val;
  *dtlcontrol=1;
  *xlpos=xl_pos;
  *ylpos=yl_pos;
  *jldt=j_ldt;
  *kldt=k_ldt;

  /* Diagnostic dump of the (placeholder) limiting cell when dt is too small. */
  if(small != 0) {
    printf("Timestep information:\n");
    printf("j, k                 :%i %i \n",j_ldt,k_ldt);
    printf("x, y                 :%f %f \n",xl_pos,yl_pos);
    printf("timestep : %f\n",dt_min_val);
    printf("Cell velocities;\n");
    printf("%f %f \n",xvel0[FTNREF2D(j_ldt  ,k_ldt  ,x_max+5,x_min-2,y_min-2)],yvel0[FTNREF2D(j_ldt  ,k_ldt  ,x_max+5,x_min-2,y_min-2)]);
    printf("%f %f \n",xvel0[FTNREF2D(j_ldt+1,k_ldt  ,x_max+5,x_min-2,y_min-2)],yvel0[FTNREF2D(j_ldt+1,k_ldt  ,x_max+5,x_min-2,y_min-2)]);
    printf("%f %f \n",xvel0[FTNREF2D(j_ldt+1,k_ldt+1,x_max+5,x_min-2,y_min-2)],yvel0[FTNREF2D(j_ldt+1,k_ldt+1,x_max+5,x_min-2,y_min-2)]);
    printf("%f %f \n",xvel0[FTNREF2D(j_ldt  ,k_ldt+1,x_max+5,x_min-2,y_min-2)],yvel0[FTNREF2D(j_ldt  ,k_ldt+1,x_max+5,x_min-2,y_min-2)]);
    printf("density, energy, pressure, soundspeed \n");
    printf("%f %f %f %f \n",density0[FTNREF2D(j_ldt,k_ldt,x_max+4,x_min-2,y_min-2)],energy0[FTNREF2D(j_ldt,k_ldt,x_max+4,x_min-2,y_min-2)],pressure[FTNREF2D(j_ldt,k_ldt,x_max+4,x_min-2,y_min-2)],soundspeed[FTNREF2D(j_ldt,k_ldt,x_max+4,x_min-2,y_min-2)]);
  }

}
