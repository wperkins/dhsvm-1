! ----------------------------------------------------------------
! file: mass1_dhsvm_api.f90
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Battelle Memorial Institute
! Pacific Northwest Laboratory
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Created February  4, 2019 by William A. Perkins
! Last Change: 2019-02-08 15:16:47 d3g096
! ----------------------------------------------------------------

! ----------------------------------------------------------------
!  FUNCTION mass1_create
! ----------------------------------------------------------------
FUNCTION mass1_create(c_cfgdir, c_outdir, start, end, dotemp) RESULT(net) BIND(c)
  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module
  IMPLICIT NONE
  TYPE (c_ptr) :: net
  TYPE (c_ptr), VALUE :: c_cfgdir, c_outdir
  TYPE (DHSVM_date), INTENT(INOUT) :: start, end
  INTEGER(KIND=C_INT), VALUE :: dotemp

  TYPE (DHSVM_network), POINTER :: f_net
  CHARACTER (LEN=1024) :: cfgdir, outdir
  LOGICAL :: f_dotemp

  CALL c2fstring(c_cfgdir, cfgdir)
  CALL c2fstring(c_outdir, outdir)

  ALLOCATE(f_net)
  ALLOCATE(f_net%net)
  f_net%net = network()
  f_dotemp = (dotemp .NE. 0)

  CALL mass1_initialize(f_net, cfgdir, outdir, start, end, f_dotemp)

  net = C_LOC(f_net)

END FUNCTION mass1_create

! ----------------------------------------------------------------
! SUBROUTINE mass1_route
! ----------------------------------------------------------------
SUBROUTINE mass1_route(cnet, ddate)
  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module


  IMPLICIT NONE

  TYPE (C_PTR), VALUE :: cnet
  TYPE (DHSVM_date) :: ddate
  TYPE (DHSVM_network), POINTER :: dnet
  DOUBLE PRECISION :: time

  CALL C_F_POINTER(cnet, dnet)

  time = dhsvm_to_decimal(ddate)

  CALL dnet%net%run_to(time)

END SUBROUTINE mass1_route



! ----------------------------------------------------------------
! SUBROUTINE mass1_update_latq
! ----------------------------------------------------------------
SUBROUTINE mass1_update_latq(cnet, linkid, latq, ddate)
  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module

  IMPLICIT NONE
  TYPE (C_PTR), VALUE :: cnet
  INTEGER(KIND=C_INT), VALUE :: linkid
  REAL(KIND=C_FLOAT), VALUE :: latq !volume rate
  TYPE (DHSVM_date) :: ddate

  DOUBLE PRECISION :: lq(1), llen, time
  TYPE (DHSVM_network), POINTER :: dnet
  CLASS (link_t), POINTER :: link
  TYPE (time_series_rec), POINTER :: ts

  CALL C_F_POINTER(cnet, dnet)

  link => dnet%link_lookup(linkid)%p
  llen = link%length()

  ! assume everything is in English units
  lq = latq/llen

  time = dhsvm_to_decimal(ddate)
  ts => link%latbc%table()
  CALL time_series_push(ts, time, lq)

END SUBROUTINE mass1_update_latq

! ----------------------------------------------------------------
!  FUNCTION mass1_link_outflow
! ----------------------------------------------------------------
FUNCTION mass1_link_outflow(cnet, linkid) RESULT (q) BIND(c)
  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module

  IMPLICIT NONE
  REAL(KIND=C_DOUBLE) :: q
  TYPE (C_PTR), VALUE :: cnet
  INTEGER(KIND=C_INT), VALUE :: linkid
  TYPE (DHSVM_network), POINTER :: dnet
  CLASS (link_t), POINTER :: link

  CALL C_F_POINTER(cnet, dnet)

  link => dnet%link_lookup(linkid)%p

  q = link%q_down()

END FUNCTION mass1_link_outflow

! ----------------------------------------------------------------
!  FUNCTION mass1_link_inflow
! ----------------------------------------------------------------
FUNCTION mass1_link_inflow(cnet, linkid) RESULT (q) BIND(c)

  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module

  IMPLICIT NONE
  REAL(KIND=C_DOUBLE) :: q
  TYPE (C_PTR), VALUE :: cnet
  INTEGER(KIND=C_INT), VALUE :: linkid
  TYPE (DHSVM_network), POINTER :: dnet
  CLASS (link_t), POINTER :: link

  CALL C_F_POINTER(cnet, dnet)

  link => dnet%link_lookup(linkid)%p

  q = link%q_up()

END FUNCTION mass1_link_inflow


! ----------------------------------------------------------------
! SUBROUTINE mass1_write_hotstart
! ----------------------------------------------------------------
SUBROUTINE mass1_write_hotstart(cnet, cname)

  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module
  IMPLICIT NONE
  TYPE (C_PTR), VALUE :: cnet
  TYPE (C_PTR), VALUE :: cname
  CHARACTER (LEN=1024) :: fname
  TYPE (DHSVM_network), POINTER :: dnet

  CALL C_F_POINTER(cnet, dnet)
  CALL c2fstring(cname, fname)

  dnet%net%config%restart_save_file = fname
  CALL dnet%net%write_restart()
END SUBROUTINE mass1_write_hotstart


! ----------------------------------------------------------------
! SUBROUTINE mass1_read_hotstart
! ----------------------------------------------------------------
SUBROUTINE mass1_read_hotstart(cnet, cname) BIND(c)
  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module
  IMPLICIT NONE
  TYPE (C_PTR), VALUE :: cnet
  TYPE (C_PTR), VALUE :: cname
  CHARACTER (LEN=1024) :: fname
  TYPE (DHSVM_network), POINTER :: dnet

  CALL C_F_POINTER(cnet, dnet)
  CALL c2fstring(cname, fname)

  dnet%net%config%restart_load_file = fname
  CALL dnet%net%read_restart()

END SUBROUTINE mass1_read_hotstart

  
! ----------------------------------------------------------------
! SUBROUTINE mass1_destroy
! ----------------------------------------------------------------
SUBROUTINE mass1_destroy(cnet) BIND(c)
  USE, INTRINSIC :: iso_c_binding
  USE mass1_dhsvm_module
  IMPLICIT NONE
  TYPE (C_PTR), VALUE :: cnet
  TYPE (DHSVM_network), POINTER :: dnet

  CALL C_F_POINTER(cnet, dnet)
  DEALLOCATE(dnet%link_lookup)
  DEALLOCATE(dnet%net)
  DEALLOCATE(dnet)

END SUBROUTINE mass1_destroy
