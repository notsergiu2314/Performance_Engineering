!Crown Copyright 2012 AWE.
!
! This file is part of CloverLeaf.
!
! CloverLeaf is free software: you can redistribute it and/or modify it under 
! the terms of the GNU General Public License as published by the 
! Free Software Foundation, either version 3 of the License, or (at your option) 
! any later version.
!
! CloverLeaf is distributed in the hope that it will be useful, but 
! WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
! FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more 
! details.
!
! You should have received a copy of the GNU General Public License along with 
! CloverLeaf. If not, see http://www.gnu.org/licenses/.

!>  @brief Momentum advection driver
!>  @author Wayne Gaudin
!>  @details Invokes the user specified momentum advection kernel.

MODULE advec_mom_driver_module

CONTAINS

  SUBROUTINE advec_mom_driver(tile,which_vel,direction,sweep_number)

    USE clover_module
    USE advec_mom_kernel_mod

    IMPLICIT NONE

    INTEGER :: tile,which_vel,direction,sweep_number

    IF(use_fortran_kernels)THEN
      IF(which_vel.EQ.1) THEN
        CALL advec_mom_kernel(chunk%tiles(tile)%t_xmin,            &
          chunk%tiles(tile)%t_xmax,              &
          chunk%tiles(tile)%t_ymin,              &
          chunk%tiles(tile)%t_ymax,              &
          chunk%tiles(tile)%field%xvel1,         &
          chunk%tiles(tile)%field%mass_flux_x,   &
          chunk%tiles(tile)%field%vol_flux_x,    &
          chunk%tiles(tile)%field%mass_flux_y,   &
          chunk%tiles(tile)%field%vol_flux_y,    &
          chunk%tiles(tile)%field%volume,        &
          chunk%tiles(tile)%field%density1,      &
          chunk%tiles(tile)%field%work_array1,   &
          chunk%tiles(tile)%field%work_array2,   &
          chunk%tiles(tile)%field%work_array3,   &
          chunk%tiles(tile)%field%work_array4,   &
          chunk%tiles(tile)%field%work_array5,   &
          chunk%tiles(tile)%field%work_array6,   &
          chunk%tiles(tile)%field%celldx,        &
          chunk%tiles(tile)%field%celldy,        &
          which_vel,                             &
          sweep_number,                          &
          direction                              )
      ELSE
        CALL advec_mom_kernel(chunk%tiles(tile)%t_xmin,            &
          chunk%tiles(tile)%t_xmax,              &
          chunk%tiles(tile)%t_ymin,              &
          chunk%tiles(tile)%t_ymax,              &
          chunk%tiles(tile)%field%yvel1,         &
          chunk%tiles(tile)%field%mass_flux_x,   &
          chunk%tiles(tile)%field%vol_flux_x,    &
          chunk%tiles(tile)%field%mass_flux_y,   &
          chunk%tiles(tile)%field%vol_flux_y,    &
          chunk%tiles(tile)%field%volume,        &
          chunk%tiles(tile)%field%density1,      &
          chunk%tiles(tile)%field%work_array1,   &
          chunk%tiles(tile)%field%work_array2,   &
          chunk%tiles(tile)%field%work_array3,   &
          chunk%tiles(tile)%field%work_array4,   &
          chunk%tiles(tile)%field%work_array5,   &
          chunk%tiles(tile)%field%work_array6,   &
          chunk%tiles(tile)%field%celldx,        &
          chunk%tiles(tile)%field%celldy,        &
          which_vel,                             &
          sweep_number,                          &
          direction                              )
      ENDIF
    ELSEIF(use_C_kernels)THEN
      ! M3-1: the direction-only helpers (work_array1/2/3/6) were built by
      ! advec_mom_prep_driver once per sweep; here only the per-component part
      ! runs. work_array4 is mom_flux; work_array5 (pre_vol) is no longer used.
      IF(which_vel.EQ.1) THEN
        CALL advec_mom_vel_c(chunk%tiles(tile)%t_xmin,            &
          chunk%tiles(tile)%t_xmax,              &
          chunk%tiles(tile)%t_ymin,              &
          chunk%tiles(tile)%t_ymax,              &
          chunk%tiles(tile)%field%xvel1,         &
          chunk%tiles(tile)%field%work_array1,   &
          chunk%tiles(tile)%field%work_array2,   &
          chunk%tiles(tile)%field%work_array3,   &
          chunk%tiles(tile)%field%work_array4,   &
          chunk%tiles(tile)%field%celldx,        &
          chunk%tiles(tile)%field%celldy,        &
          direction                              )
      ELSE
        CALL advec_mom_vel_c(chunk%tiles(tile)%t_xmin,            &
          chunk%tiles(tile)%t_xmax,              &
          chunk%tiles(tile)%t_ymin,              &
          chunk%tiles(tile)%t_ymax,              &
          chunk%tiles(tile)%field%yvel1,         &
          chunk%tiles(tile)%field%work_array1,   &
          chunk%tiles(tile)%field%work_array2,   &
          chunk%tiles(tile)%field%work_array3,   &
          chunk%tiles(tile)%field%work_array4,   &
          chunk%tiles(tile)%field%celldx,        &
          chunk%tiles(tile)%field%celldy,        &
          direction                              )
      ENDIF
    ENDIF

  END SUBROUTINE advec_mom_driver

  ! M3-1: direction-only part of the momentum advection, called once per sweep
  ! and tile before the two advec_mom_driver calls. It fills
  !   work_array1 = node_flux, work_array2 = node_mass_post,
  !   work_array3 = node_mass_pre, work_array6 = post_vol
  ! for both velocity components. The Fortran kernel still computes these
  ! inside advec_mom_kernel itself, so this is a no-op for that build.
  SUBROUTINE advec_mom_prep_driver(tile,direction,sweep_number)

    USE clover_module

    IMPLICIT NONE

    INTEGER :: tile,direction,sweep_number

    IF(use_C_kernels)THEN
      CALL advec_mom_prep_c(chunk%tiles(tile)%t_xmin,            &
        chunk%tiles(tile)%t_xmax,              &
        chunk%tiles(tile)%t_ymin,              &
        chunk%tiles(tile)%t_ymax,              &
        chunk%tiles(tile)%field%mass_flux_x,   &
        chunk%tiles(tile)%field%vol_flux_x,    &
        chunk%tiles(tile)%field%mass_flux_y,   &
        chunk%tiles(tile)%field%vol_flux_y,    &
        chunk%tiles(tile)%field%volume,        &
        chunk%tiles(tile)%field%density1,      &
        chunk%tiles(tile)%field%work_array1,   &
        chunk%tiles(tile)%field%work_array2,   &
        chunk%tiles(tile)%field%work_array3,   &
        chunk%tiles(tile)%field%work_array6,   &
        sweep_number,                          &
        direction                              )
    ENDIF

  END SUBROUTINE advec_mom_prep_driver

END MODULE advec_mom_driver_module
