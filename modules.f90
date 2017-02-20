
!***************************************************************
!            Pacific Northwest National Laboratory
!***************************************************************
!
! NAME:	modules
!
! VERSION and DATE: MASS1 v0.75 3/25/1998
!
! PURPOSE: contains all module-level variable declarations
!
! RETURNS: void
!
! REQUIRED:
!
! LOCAL VARIABLES:
!
! COMMENTS:
!
!
! MOD HISTORY:
!	changed maxlevels to 1500 from 1000; mcr 10/16/1997
!   added variables for bed shear, friction slope, froude number,
!         top width - enhanced output; mcr 11/21/1997
!   added variables for uniform lateral inflows; mcr 3/25/98
!
!
!***************************************************************
! CVS ID: $Id$
! Last Change: Mon Feb 21 11:54:55 2011 by William A. Perkins <d3g096@PE10900.pnl.gov>
!----------------------------------------------------------
MODULE general_vars

  DOUBLE PRECISION, SAVE :: time,time_begin,time_end,delta_t,time_mult,time_step
  INTEGER, SAVE :: units, channel_length_units
  INTEGER, SAVE :: time_units,debug_print
  INTEGER, SAVE :: lateral_inflow_flag
  INTEGER, SAVE :: diffusion_flag,degass_flag
  INTEGER, SAVE :: print_output_flag, plot_output_flag
  INTEGER, SAVE :: maxlinks,maxpoint,scalar_steps
  INTEGER, SAVE :: dsbc_type
  DOUBLE PRECISION, SAVE :: res_coeff,grav
  DOUBLE PRECISION, SAVE :: unit_weight_h2o,density_h2o
  CHARACTER (LEN =120) :: config_version

  DOUBLE PRECISION, SAVE :: depth_threshold, depth_minimum

  INTEGER, SAVE :: print_freq

END MODULE general_vars
!------------------------------------------------------------------
MODULE date_vars

  INTEGER, SAVE :: time_option
  CHARACTER (LEN=10) :: date_string, date_run_begins, date_run_ends
  CHARACTER (LEN=8) :: time_string, time_run_begins, time_run_ends

END MODULE date_vars

!----------------------------------------------------------
MODULE logicals

  LOGICAL, SAVE :: do_flow,do_gas,do_temp,do_printout,do_gageout,do_profileout
  LOGICAL, SAVE :: do_restart,do_hotstart
  LOGICAL, SAVE :: temp_diffusion, temp_exchange
  LOGICAL, SAVE :: gas_diffusion, gas_exchange
  LOGICAL, SAVE :: print_sections,write_sections,read_sections
  LOGICAL, SAVE :: do_latflow
  LOGICAL, SAVE :: do_accumulate

END MODULE logicals

!----------------------------------------------------------
MODULE file_vars

  CHARACTER (LEN = 100), SAVE :: filename(20)
  INTEGER, SAVE :: ii,fileunit(20) = (/(ii,ii=20,39)/)

END MODULE file_vars

!-----------------------------------------------------

!----------------------------------------------------------
MODULE link_vars

  INTEGER, DIMENSION(:),ALLOCATABLE, SAVE :: maxpoints,linkname,linkorder,comporder,linktype,input_option
  INTEGER, DIMENSION(:),ALLOCATABLE, SAVE :: linkbc_table,ds_conlink,&
       & dsbc_table,transbc_table,tempbc_table,latflowbc_table,lattransbc_table,lattempbc_table
  INTEGER, DIMENSION(:),ALLOCATABLE, SAVE :: met_zone
  DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE, SAVE :: crest

  DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE, SAVE :: lpiexp

END MODULE link_vars

!----------------------------------------------------------
MODULE point_vars

  USE cross_section

  DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE, SAVE :: x, q,thalweg,y,manning,vel,kstrick
  DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE, SAVE :: area, area_old, q_old,y_old,k_diff
  DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE, SAVE :: top_width, hyd_radius, froude_num, friction_slope, bed_shear
  DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE, SAVE :: lateral_inflow, lateral_inflow_old
  DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE, SAVE :: courant_num, diffuse_num
  INTEGER, DIMENSION(:,:),ALLOCATABLE, SAVE :: section_number

  TYPE :: ptsection_t
     CLASS (xsection_t), POINTER :: wrap
  END type ptsection_t
  TYPE (ptsection_t), DIMENSION(:,:), ALLOCATABLE, SAVE :: ptsection

END MODULE point_vars

!----------------------------------------------------------
MODULE flow_coeffs

  DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE, SAVE :: e,f,l,m,n

END MODULE flow_coeffs


!----------------------------------------------------------
MODULE fluvial_coeffs

  ! REAL, SAVE :: alpha=1.0,beta=0.5,theta=1.0,q1,q2,a1,a2,b1,b2,k1,k2	&
  !               ,ky1,ky2,y2,y1
  DOUBLE PRECISION, SAVE :: alpha=1.0,beta=0.5,theta=1.0,q1,q2,a1,a2,b1,b2,k1,k2,ky1,ky2,y2,y1
  DOUBLE PRECISION, SAVE :: d1, d2, fr1, fr2

END MODULE fluvial_coeffs

!---------------------------------------------------------
MODULE transport_vars

  DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE, SAVE :: c,k_surf
  DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE, SAVE :: dxx
  DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE, SAVE :: temp

END MODULE transport_vars
