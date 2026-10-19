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
 *  @brief C momentum advection kernel
 *  @author Wayne Gaudin
 *  @details Performs a second order advective remap on the vertex momentum
 *  using van-Leer limiting and directional splitting.
 *
 *  M3 restructuring (see report, "Byte reductions" (1), (3), (6) and the
 *  time-only changes T1, T3). The original single kernel was called once per
 *  velocity component (xvel1, then yvel1) and recomputed four helper arrays
 *  that depend only on the sweep direction, i.e. identically for both calls.
 *  It is now split in two entry points:
 *
 *    advec_mom_prep_c  : once per sweep and tile. Builds post_vol, node_flux,
 *                        node_mass_post and node_mass_pre.
 *    advec_mom_vel_c   : once per velocity component. Builds mom_flux from the
 *                        limited upwind velocity and applies the update to vel1.
 *
 *  The Fortran driver (advec_mom_driver.f90) calls prep, then vel for xvel1
 *  and vel for yvel1. Nothing between those calls touches the work arrays.
 *
 *  pre_vol (work_array5 in the driver) was written over the whole haloed grid
 *  and never read, by either this kernel or any other; the original source
 *  asked to keep it for fidelity with the Fortran method. It is dropped here
 *  because the store (plus its read-for-ownership) was pure DRAM traffic.
 */

#include <stdio.h>
#include <stdlib.h>
#include "ftocmacros.h"
#include "papi_prof.h"
#include <math.h>

/* Index helpers. Node-sized and flux arrays have x_max+5 entries per row
 * (xvel/yvel, mass_flux_x, vol_flux_x and all the work arrays); cell-sized
 * arrays have x_max+4 (volume, density1, mass_flux_y, vol_flux_y). Both start
 * at (x_min-2, y_min-2). j runs fastest, so consecutive j are contiguous. */
#define IDXN(j,k) FTNREF2D((j),(k),x_max+5,x_min-2,y_min-2)
#define IDXC(j,k) FTNREF2D((j),(k),x_max+4,x_min-2,y_min-2)

/* ------------------------------------------------------------------------
 * Part 1: direction-only helpers, once per sweep.
 *
 * On OpenMP barriers (T1). Every "#pragma omp for" ends with an implicit
 * barrier. A "nowait" is added only where the next loop can be proven not to
 * read what another thread may still be writing:
 *   - the post_vol loop and the node_flux loop are independent, so post_vol
 *     carries nowait; the barrier after node_flux then protects both before
 *     node_mass_post reads post_vol with a k-1 stencil.
 *   - node_mass_post and node_mass_pre have the same k range and
 *     schedule(static); OpenMP then guarantees the same row -> thread mapping,
 *     and node_mass_pre reads node_mass_post only in its own row k. So
 *     node_mass_post carries nowait.
 *   - node_mass_pre also reads node_flux with a k-1 stencil in direction 2,
 *     but node_flux finished at its own barrier, so that is safe too.
 *
 * On streaming stores (6). Each output array below is written exactly once
 * per iteration, contiguously in j, and is not loaded anywhere in its own
 * loop. That is the pattern the core's write-streaming detector needs to skip
 * the read-for-ownership on the store; whether it engages is measured with
 * the DDR-controller counters, not assumed. An explicit non-temporal store
 * (stnp) could force it, but GCC has no portable builtin for it and it cannot
 * be validated on the development machine, so it is left out for now.
 * ---------------------------------------------------------------------- */
void advec_mom_prep_c_(int *xmin,int *xmax,int *ymin,int *ymax,
                       double *mass_flux_x,
                       double *vol_flux_x,
                       double *mass_flux_y,
                       double *vol_flux_y,
                       double *volume,
                       double *density1,
                       double *node_flux,
                       double *node_mass_post,
                       double *node_mass_pre,
                       double *post_vol,
                          int *swp_nmbr,
                          int *drctn)
{
  int x_min=*xmin;
  int x_max=*xmax;
  int y_min=*ymin;
  int y_max=*ymax;
  int sweep_number=*swp_nmbr;
  int direction=*drctn;

  int j,k,mom_sweep;

  /* 1 = x sweep first, 2 = y sweep first, 3 = x sweep second, 4 = y sweep second */
  mom_sweep=direction+2*(sweep_number-1);

#pragma omp parallel
 {
  PROF_BEGIN(PROF_ADVEC_MOM);

  /* post_vol: the cell volume after this sweep's remap. In the first sweep of
   * a step the cell has already been moved by the *other* direction's volume
   * flux; in the second sweep both fluxes have been applied and the volume is
   * back to the Lagrangian one. Computed over the full haloed grid because
   * node_mass_post below reads it with a (j-1,k-1) stencil. */
  if(mom_sweep==1){
#pragma omp for private(j) nowait
    for (k=y_min-2;k<=y_max+2;k++) {
#pragma omp simd
      for (j=x_min-2;j<=x_max+2;j++) {
        post_vol[IDXN(j,k)]=volume[IDXC(j,k)]
                           +vol_flux_y[IDXC(j,k+1)]
                           -vol_flux_y[IDXC(j,k)];
      }
    }
  } else if(mom_sweep==2){
#pragma omp for private(j) nowait
    for (k=y_min-2;k<=y_max+2;k++) {
#pragma omp simd
      for (j=x_min-2;j<=x_max+2;j++) {
        post_vol[IDXN(j,k)]=volume[IDXC(j,k)]
                           +vol_flux_x[IDXN(j+1,k)]
                           -vol_flux_x[IDXN(j,k)];
      }
    }
  } else {            /* mom_sweep 3 or 4 */
#pragma omp for private(j) nowait
    for (k=y_min-2;k<=y_max+2;k++) {
#pragma omp simd
      for (j=x_min-2;j<=x_max+2;j++) {
        post_vol[IDXN(j,k)]=volume[IDXC(j,k)];
      }
    }
  }

  if(direction==1) {
    /* node_flux: mass flux through the vertical face centred on node (j,k),
     * the average of the four surrounding cell-face mass fluxes. Independent
     * of post_vol, hence the nowait on the loop above. */
#pragma omp for private(j) schedule(static)
    for (k=y_min;k<=y_max+1;k++) {
#pragma omp simd
      for (j=x_min-2;j<=x_max+2;j++) {
        node_flux[IDXN(j,k)]=0.25
                            *(mass_flux_x[IDXN(j  ,k-1)]
                             +mass_flux_x[IDXN(j  ,k  )]
                             +mass_flux_x[IDXN(j+1,k-1)]
                             +mass_flux_x[IDXN(j+1,k  )]);
      }
    }
    /* node_mass_post: mass of the node control volume after the remap, the
     * average of the four surrounding cell masses (density * post_vol). */
#pragma omp for private(j) schedule(static) nowait
    for (k=y_min;k<=y_max+1;k++) {
#pragma omp simd
      for (j=x_min-1;j<=x_max+2;j++) {
        node_mass_post[IDXN(j,k)]=0.25
                                 *(density1[IDXC(j  ,k-1)]*post_vol[IDXN(j  ,k-1)]
                                  +density1[IDXC(j  ,k  )]*post_vol[IDXN(j  ,k  )]
                                  +density1[IDXC(j-1,k-1)]*post_vol[IDXN(j-1,k-1)]
                                  +density1[IDXC(j-1,k  )]*post_vol[IDXN(j-1,k  )]);
      }
    }
    /* node_mass_pre: the node mass before the remap, i.e. post mass with the
     * net node flux undone. Same rows as node_mass_post -> no barrier needed
     * between them (see header). */
#pragma omp for private(j) schedule(static)
    for (k=y_min;k<=y_max+1;k++) {
#pragma omp simd
      for (j=x_min-1;j<=x_max+2;j++) {
        node_mass_pre[IDXN(j,k)]=node_mass_post[IDXN(j,k)]
                                -node_flux[IDXN(j-1,k)]+node_flux[IDXN(j,k)];
      }
    }
  }
  else if(direction==2){
    /* Same three helpers for the y direction: the stencils turn 90 degrees. */
#pragma omp for private(j) schedule(static)
    for (k=y_min-2;k<=y_max+2;k++) {
#pragma omp simd
      for (j=x_min;j<=x_max+1;j++) {
        node_flux[IDXN(j,k)]=0.25
                            *(mass_flux_y[IDXC(j-1,k  )]
                             +mass_flux_y[IDXC(j  ,k  )]
                             +mass_flux_y[IDXC(j-1,k+1)]
                             +mass_flux_y[IDXC(j  ,k+1)]);
      }
    }
#pragma omp for private(j) schedule(static) nowait
    for (k=y_min-1;k<=y_max+2;k++) {
#pragma omp simd
      for (j=x_min;j<=x_max+1;j++) {
        node_mass_post[IDXN(j,k)]=0.25
                                 *(density1[IDXC(j  ,k-1)]*post_vol[IDXN(j  ,k-1)]
                                  +density1[IDXC(j  ,k  )]*post_vol[IDXN(j  ,k  )]
                                  +density1[IDXC(j-1,k-1)]*post_vol[IDXN(j-1,k-1)]
                                  +density1[IDXC(j-1,k  )]*post_vol[IDXN(j-1,k  )]);
      }
    }
#pragma omp for private(j) schedule(static)
    for (k=y_min-1;k<=y_max+2;k++) {
#pragma omp simd
      for (j=x_min;j<=x_max+1;j++) {
        node_mass_pre[IDXN(j,k)]=node_mass_post[IDXN(j,k)]
                                -node_flux[IDXN(j,k-1)]+node_flux[IDXN(j,k)];
      }
    }
  }

  PROF_END(PROF_ADVEC_MOM);
 }
}

/* ------------------------------------------------------------------------
 * Part 2: per velocity component.
 *
 * Loop 1 builds mom_flux, the momentum carried through the node face, from a
 * van Leer limited upwind velocity. Loop 2 applies it to vel1.
 *
 * Upwind selection (T3). The original code chose the upwind/donor/downwind
 * node indices with an if/else on the sign of node_flux and then loaded
 * through those indices. That is a data-dependent branch plus indirect
 * loads, which stops vectorisation. Here all four candidate neighbours are
 * loaded unconditionally (they are contiguous) and the right ones are picked
 * with a select on the sign. The limiter is likewise always evaluated and
 * then selected against 0 where the original branch would have skipped it.
 * Every arithmetic operation is the same as before and in the same order,
 * so the results are bit-identical; only the control flow changed.
 * GCC still refuses to if-convert the loop under the default -ftrapping-math,
 * because it sinks the limiter's divisions under the select and may then not
 * speculate them; the Makefile therefore adds -fno-trapping-math (GNU, ARM).
 * With GCC 13 on x86 all 13 loops of this file vectorise with that flag.
 *
 *   node_flux >= 0 (flow in +j):  upwind = j-1, donor = j,   downwind = j+1
 *   node_flux <  0 (flow in -j):  upwind = j+2, donor = j+1, downwind = j
 *   dif = the cell width used in the limiter: donor side when flow is -j,
 *         upwind side otherwise (as in the original).
 *
 * Barriers (T1). In direction 1 both loops run over the same k rows with
 * schedule(static), loop 1 reads vel1 only in its own row and loop 2 reads
 * mom_flux only in its own row, so loop 1 carries nowait. In direction 2 the
 * stencils cross rows (k-1..k+2) and the barrier stays.
 *
 * Streaming stores (6). The vel1 update reads vel1[i] in the same iteration,
 * so the line is already in L1 when it is stored and no read-for-ownership
 * is paid; a non-temporal store here would save nothing. mom_flux in loop 1
 * is a pure output and does qualify, see the note in advec_mom_prep_c.
 * ---------------------------------------------------------------------- */
void advec_mom_vel_c_(int *xmin,int *xmax,int *ymin,int *ymax,
                      double *vel1,
                      double *node_flux,
                      double *node_mass_post,
                      double *node_mass_pre,
                      double *mom_flux,
                      double *celldx,
                      double *celldy,
                         int *drctn)
{
  int x_min=*xmin;
  int x_max=*xmax;
  int y_min=*ymin;
  int y_max=*ymax;
  int direction=*drctn;

  int j,k;

#pragma omp parallel
 {
  PROF_BEGIN(PROF_ADVEC_MOM);

  if(direction==1) {
#pragma omp for private(j) schedule(static) nowait
    for (k=y_min;k<=y_max+1;k++) {
#pragma omp simd
      for (j=x_min-1;j<=x_max+1;j++) {
        const double nf  = node_flux[IDXN(j,k)];
        const int    neg = (nf < 0.0);

        /* the four candidate velocities around node j, contiguous loads */
        const double v_m1 = vel1[IDXN(j-1,k)];
        const double v_0  = vel1[IDXN(j  ,k)];
        const double v_p1 = vel1[IDXN(j+1,k)];
        const double v_p2 = vel1[IDXN(j+2,k)];

        const double v_up  = neg ? v_p2 : v_m1;   /* vel1[upwind]   */
        const double v_don = neg ? v_p1 : v_0;    /* vel1[donor]    */
        const double v_dwn = neg ? v_0  : v_p1;   /* vel1[downwind] */
        /* donor-side node mass and limiter cell width: load both candidates
         * unconditionally and select the scalar, otherwise GCC turns the
         * conditional load into a branch and gives up on vectorising */
        const double m_0   = node_mass_pre[IDXN(j  ,k)];
        const double m_p1  = node_mass_pre[IDXN(j+1,k)];
        const double w_m1  = celldx[FTNREF1D(j-1,x_min-2)];
        const double width = celldx[FTNREF1D(j  ,x_min-2)];
        const double w_p1  = celldx[FTNREF1D(j+1,x_min-2)];
        const double m_don = neg ? m_p1 : m_0;    /* node_mass_pre[donor] */
        const double w_dif = neg ? w_p1 : w_m1;   /* celldx[dif]          */

        /* sigma: fraction of the donor node mass that crosses the face */
        const double sigma   = fabs(nf)/m_don;
        const double vdiffuw = v_don - v_up;
        const double vdiffdw = v_dwn - v_don;
        const double auw     = fabs(vdiffuw);
        const double adw     = fabs(vdiffdw);
        const double wind    = (vdiffdw <= 0.0) ? -1.0 : 1.0;

        /* van Leer limiter: second order where the velocity is monotone
         * (vdiffuw and vdiffdw have the same sign), first order otherwise */
        const double lim     = wind*MIN(width*((2.0-sigma)*adw/width
                                               +(1.0+sigma)*auw/w_dif)/6.0,
                                        MIN(auw,adw));
        const double limiter = (vdiffuw*vdiffdw > 0.0) ? lim : 0.0;

        /* advected velocity times mass flux = momentum flux through the face */
        mom_flux[IDXN(j,k)] = (v_don + (1.0-sigma)*limiter)*nf;
      }
    }

    /* Momentum balance: new velocity = (old momentum + net momentum flux)
     * divided by the new node mass. */
#pragma omp for private(j) schedule(static)
    for (k=y_min;k<=y_max+1;k++) {
#pragma omp simd
      for (j=x_min;j<=x_max+1;j++) {
        vel1[IDXN(j,k)]=(vel1[IDXN(j,k)]*node_mass_pre[IDXN(j,k)]
                         +mom_flux[IDXN(j-1,k)]
                         -mom_flux[IDXN(j  ,k)])
                         /node_mass_post[IDXN(j,k)];
      }
    }
  }
  else if(direction==2){
    /* Same scheme along k: the candidate nodes are k-1, k, k+1, k+2 in the
     * same column j, and the width comes from celldy. */
#pragma omp for private(j) schedule(static)
    for (k=y_min-1;k<=y_max+1;k++) {
#pragma omp simd
      for (j=x_min;j<=x_max+1;j++) {
        const double nf  = node_flux[IDXN(j,k)];
        const int    neg = (nf < 0.0);

        const double v_m1 = vel1[IDXN(j,k-1)];
        const double v_0  = vel1[IDXN(j,k  )];
        const double v_p1 = vel1[IDXN(j,k+1)];
        const double v_p2 = vel1[IDXN(j,k+2)];

        const double v_up  = neg ? v_p2 : v_m1;
        const double v_don = neg ? v_p1 : v_0;
        const double v_dwn = neg ? v_0  : v_p1;
        const double m_0   = node_mass_pre[IDXN(j,k  )];
        const double m_p1  = node_mass_pre[IDXN(j,k+1)];
        const double w_m1  = celldy[FTNREF1D(k-1,y_min-2)];
        const double width = celldy[FTNREF1D(k  ,y_min-2)];
        const double w_p1  = celldy[FTNREF1D(k+1,y_min-2)];
        const double m_don = neg ? m_p1 : m_0;
        const double w_dif = neg ? w_p1 : w_m1;

        const double sigma   = fabs(nf)/m_don;
        const double vdiffuw = v_don - v_up;
        const double vdiffdw = v_dwn - v_don;
        const double auw     = fabs(vdiffuw);
        const double adw     = fabs(vdiffdw);
        const double wind    = (vdiffdw <= 0.0) ? -1.0 : 1.0;
        const double lim     = wind*MIN(width*((2.0-sigma)*adw/width
                                               +(1.0+sigma)*auw/w_dif)/6.0,
                                        MIN(auw,adw));
        const double limiter = (vdiffuw*vdiffdw > 0.0) ? lim : 0.0;

        mom_flux[IDXN(j,k)] = (v_don + (1.0-sigma)*limiter)*nf;
      }
    }

#pragma omp for private(j) schedule(static)
    for (k=y_min;k<=y_max+1;k++) {
#pragma omp simd
      for (j=x_min;j<=x_max+1;j++) {
        vel1[IDXN(j,k)]=(vel1[IDXN(j,k)]*node_mass_pre[IDXN(j,k)]
                         +mom_flux[IDXN(j,k-1)]
                         -mom_flux[IDXN(j,k  )])
                         /node_mass_post[IDXN(j,k)];
      }
    }
  }

  PROF_END(PROF_ADVEC_MOM);
 }
}
