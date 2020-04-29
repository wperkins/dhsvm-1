!***************************************************************
! Copyright (c) 2017 Battelle Memorial Institute
! Licensed under modified BSD License. A copy of this license can be
! found in the LICENSE file in the top level directory of this
! distribution.
!***************************************************************
! ----------------------------------------------------------------
! file: scalar_module.f90
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Battelle Memorial Institute
! Pacific Northwest Laboratory
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Created January  7, 2019 by William A. Perkins
! Last Change: 2020-04-29 14:12:08 d3g096
! ----------------------------------------------------------------

! ----------------------------------------------------------------
! MODULE scalar_module
! ----------------------------------------------------------------
MODULE scalar_module

  USE mass1_config
  USE point_module
  USE bc_module
  USE met_zone
  USE gas_functions
  USE general_vars, ONLY: depth_minimum

  IMPLICIT NONE

  PUBLIC met_zone_t
  PUBLIC met_zone_manager_t

  ! ----------------------------------------------------------------
  ! TYPE scalar_t
  ! ----------------------------------------------------------------
  TYPE, PUBLIC :: scalar_t
     LOGICAL :: dometric
     LOGICAL :: dodiffusion
     LOGICAL :: dolatinflow
     LOGICAL :: dosource
     LOGICAL :: needmet
     LOGICAL :: istemp
     INTEGER (KIND=KIND(BC_ENUM)) :: bctype
   CONTAINS
     PROCEDURE :: output => scalar_output
     PROCEDURE :: source => scalar_source
  END type scalar_t

  INTERFACE scalar_t
     MODULE PROCEDURE new_scalar_t
  END INTERFACE scalar_t

  ! ----------------------------------------------------------------
  ! TYPE scalar_ptr
  ! ----------------------------------------------------------------
  TYPE, PUBLIC :: scalar_ptr
     CLASS (scalar_t), POINTER :: p
  END type scalar_ptr

  ! ----------------------------------------------------------------
  ! TYPE scalar_manager
  ! ----------------------------------------------------------------
  TYPE, PUBLIC :: scalar_manager
     INTEGER :: nspecies
     TYPE (scalar_ptr), POINTER :: species(:)
     INTEGER :: temp_index
   CONTAINS
     PROCEDURE :: initialize => scalar_manager_init
  END type scalar_manager
  
  ! ----------------------------------------------------------------
  ! TYPE temp_scalar
  ! ----------------------------------------------------------------
  TYPE, PUBLIC, EXTENDS(scalar_t) :: temperature
     LOGICAL :: do_friction
     LOGICAL :: do_bed
     LOGICAL :: do_limit
     LOGICAL :: do_eqlimit
   CONTAINS
     PROCEDURE :: atmospheric_flux => temperature_atmospheric_flux
     PROCEDURE :: friction => temperature_friction
     PROCEDURE :: bed_flux => temperature_bed_flux
     PROCEDURE :: source => temperature_source
  END type temperature

  INTERFACE temperature
     MODULE PROCEDURE new_temperature
  END INTERFACE temperature

  ! This is for backwards compatibility.  Throughout it's history
  ! MASS1 would let temperature go below 0 (C), which is not
  ! realistic.  This should be .TRUE. to keep temperature above zero
  ! (and below 100).  This is only affects the application of
  ! atmospheric exchange. It does not artificially correct numerical
  ! transport issues.
  LOGICAL, PUBLIC :: temperature_limits = .FALSE.

  DOUBLE PRECISION, PRIVATE, PARAMETER :: temperature_min = 0.0D0
  DOUBLE PRECISION, PRIVATE, PARAMETER :: temperature_max = 1.0D2
  

  ! ----------------------------------------------------------------
  ! TYPE tdg_scalar
  ! ----------------------------------------------------------------
  TYPE, PUBLIC, EXTENDS(scalar_t) :: tdg
   CONTAINS
     PROCEDURE :: source => tdg_source
     PROCEDURE :: output => tdg_output
  END type tdg

  INTERFACE tdg
     MODULE PROCEDURE new_tdg
  END INTERFACE tdg


CONTAINS


  ! ----------------------------------------------------------------
  !  FUNCTION new_scalar_t
  ! ----------------------------------------------------------------
  FUNCTION new_scalar_t(dometric, dodiff, dolatq, dosrc) RESULT(s)

    IMPLICIT NONE
    TYPE (scalar_t) :: s
    LOGICAL, INTENT(IN) :: dometric, dodiff, dolatq, dosrc

    s%dometric = dometric
    s%dodiffusion = dodiff
    s%dolatinflow = dolatq
    s%dosource = dosrc
    s%bctype = BC_ENUM

  END FUNCTION new_scalar_t

  ! ----------------------------------------------------------------
  ! SUBROUTINE scalar_output
  ! ----------------------------------------------------------------
  SUBROUTINE scalar_output(this, ispec, pt, cout, nout)

    IMPLICIT NONE
    CLASS(scalar_t), INTENT(IN) :: this
    INTEGER, INTENT(IN) :: ispec
    CLASS(point_t), INTENT(IN) :: pt
    DOUBLE PRECISION, INTENT(OUT) :: cout(*)
    INTEGER, INTENT(OUT) :: nout

    nout = 1
    cout(1) = pt%trans%cnow(ispec)

  END SUBROUTINE scalar_output


  ! ----------------------------------------------------------------
  !  FUNCTION scalar_source
  ! ----------------------------------------------------------------
  FUNCTION scalar_source(this, cin, pt, deltat, met) RESULT (cout)

    IMPLICIT NONE
    DOUBLE PRECISION :: cout
    CLASS(scalar_t), INTENT(IN) :: this
    TYPE (point_transport_state), INTENT(INOUT) :: pt
    DOUBLE PRECISION, INTENT(IN) :: cin, deltat
    CLASS (met_zone_t), INTENT(INOUT), POINTER :: met

    cout = cin

    ! could do radioactive decay here
    
  END FUNCTION scalar_source

  ! ----------------------------------------------------------------
  !  FUNCTION new_temperature
  ! ----------------------------------------------------------------
  FUNCTION new_temperature(dometric, dodiff, dolatq, dosrc, dofrict, dobed) RESULT(t)

    IMPLICIT NONE
    TYPE (temperature) :: t
    LOGICAL, INTENT(IN) :: dometric, dodiff, dolatq, dosrc, dofrict, dobed

    t%dometric = dometric
    t%dodiffusion = dodiff
    t%dolatinflow = dolatq
    t%dosource = dosrc
    t%bctype = TEMP_BC_TYPE
    t%needmet = t%dosource
    t%do_friction = dofrict
    t%do_bed = dobed
    t%do_limit = .FALSE.

    t%do_eqlimit = .FALSE.

  END FUNCTION new_temperature

  ! ----------------------------------------------------------------
  !  FUNCTION temperature_atmospheric_flux
  !
  ! The result is in W/m2
  ! ----------------------------------------------------------------
  FUNCTION temperature_atmospheric_flux(this, twater, attenuate, met) RESULT (flux)

    IMPLICIT NONE
    DOUBLE PRECISION  flux
    CLASS(temperature), INTENT(IN) :: this
    DOUBLE PRECISION, INTENT(IN) :: twater, attenuate
    CLASS (met_zone_t), INTENT(INOUT), POINTER :: met

    DOUBLE PRECISION :: t

    flux = 0.0
    t = twater
    
    ! Don't use a wacky temperature value
    t = MAX(temperature_min, t)
    t = MIN(temperature_max, t)

    flux = met%energy_flux(t, attenuate)
    
  END FUNCTION temperature_atmospheric_flux

  ! ----------------------------------------------------------------
  !  FUNCTION temperature_friction
  !
  ! Heat W/m2 generated by friction.
  ! ----------------------------------------------------------------
  FUNCTION temperature_friction(this, pt) RESULT (flux)

    IMPLICIT NONE
    DOUBLE PRECISION :: flux
    CLASS(temperature), INTENT(IN) :: this
    TYPE (point_transport_state), INTENT(IN) :: pt

    DOUBLE PRECISION, PARAMETER :: rho = 1000.0
    DOUBLE PRECISION, PARAMETER :: g = 9.81
    DOUBLE PRECISION :: q, twid, sf

    q = pt%hnow%q
    twid = pt%xsprop%topwidth
    sf = pt%hnow%friction_slope
    
    IF (.NOT. this%dometric) THEN
       q = q * 0.028316847
       twid = twid / 0.3048
    END IF
    
    flux = rho*g*q/twid*sf
    
  END FUNCTION temperature_friction


  ! ----------------------------------------------------------------
  !  FUNCTION temperature_bed_flux
  ! ----------------------------------------------------------------
  FUNCTION temperature_bed_flux(this, pt, twater, brad, deltat) RESULT(flux)

    IMPLICIT NONE
    DOUBLE PRECISION :: flux
    CLASS(temperature), INTENT(IN) :: this
    TYPE (point_transport_state), INTENT(INOUT) :: pt
    DOUBLE PRECISION, INTENT(IN) :: twater, brad
    DOUBLE PRECISION, INTENT(IN) :: deltat

    DOUBLE PRECISION :: gwflux, swflux

    ! pt%beddepth is the total depth of the bed, pt%bedtemp is in the
    ! middle of that depth, 

    ! flux OUT to ground water
    gwflux = pt%bedcond*(pt%bedtemp - pt%bedgwtemp)/(0.5*pt%beddepth)

    ! flux OUT to stream
    swflux = pt%bedcond*(pt%bedtemp - twater)/(0.5*pt%beddepth)

    pt%bedtempold = pt%bedtemp

    pt%bedtemp = pt%bedtempold + &
         &(brad - swflux - gwflux)*deltat/pt%beddepth/pt%beddensity/pt%bedspheat


    flux = swflux
    
  END FUNCTION temperature_bed_flux

  ! ----------------------------------------------------------------
  !  FUNCTION swrad_attenuation
  !
  ! This computes the fraction of SW radiation asorbed by the water
  ! column based on equation 2-53 of the Oregon DEQ "Heatsource"
  ! manual
  ! ----------------------------------------------------------------
  FUNCTION swrad_attenuation(depth, ismetric) RESULT (att)

    IMPLICIT NONE
    DOUBLE PRECISION :: att
    DOUBLE PRECISION, INTENT(IN) :: depth
    LOGICAL, INTENT(IN) :: ismetric
    DOUBLE PRECISION :: d

    IF (.NOT. ismetric) THEN
       d = depth/0.3048
    ELSE
       d = depth
    END IF

    IF (d .GT. depth_minimum) THEN
       att = 0.415 - 0.194*LOG10(d)
    ELSE
       att = 0.0
    END IF

    att = 1.0 - att

  END FUNCTION swrad_attenuation


  ! ----------------------------------------------------------------
  !  FUNCTION temperature_source
  ! ----------------------------------------------------------------
  FUNCTION temperature_source(this, cin, pt, deltat, met) RESULT (tout)

    IMPLICIT NONE

    DOUBLE PRECISION :: tout
    CLASS(temperature), INTENT(IN) :: this
    TYPE (point_transport_state), INTENT(INOUT) :: pt
    DOUBLE PRECISION, INTENT(IN) :: cin, deltat
    CLASS (met_zone_t), INTENT(INOUT), POINTER :: met

    DOUBLE PRECISION :: t, depth, area, width, factor, dt, flux, aflux
    DOUBLE PRECISION :: teq, tsign, fsign
    DOUBLE PRECISION :: attenuate, brad

    tout = this%scalar_t%source(cin, pt, deltat, met)

    IF (this%dosource) THEN

       IF (ASSOCIATED(met)) THEN
          depth = pt%xsprop%depth
          area = pt%xsprop%area
          width = pt%xsprop%topwidth

          IF (depth .GT. depth_minimum .AND. area .GT. 0.0) THEN

             flux = 0.0
             
             ! FIXME: metric units
             factor = 1.0/(1000.0*4186.0)*deltat*width/area
             IF (.NOT. this%dometric) THEN
                factor = factor*3.2808
             END IF 
             t = tout

             attenuate = 1.0
             
             IF (this%do_bed) THEN
                attenuate = swrad_attenuation(depth, this%dometric)
                brad = met%current%rad*(1.0 - attenuate)
                flux = flux + this%bed_flux(pt, tout, brad, deltat)
             END IF

             aflux = this%atmospheric_flux(tout, attenuate, met)

             ! FIXME: This needs to account for lateral inflow before
             ! it's useful
             ! IF (this%do_eqlimit) THEN
             !    ! The atmospheric flux should not make the temperature go
             !    ! past the equilibrium temperature, so limit the flux to
             !    ! get the temperature 99% of the way to equilibrium
             !    ! temperature.
                
             !    teq = met%equilib_temp(tout, attenuate)

             !    IF (this%do_limit) THEN
             !       teq = MAX(temperature_min, teq)
             !       teq = MIN(temperature_max, teq)
             !    END IF
                
             !    dt = (teq - tout)

             !    WRITE(*,*) tout, teq, dt, aflux, dt/factor

             !    ! If the flux indicates the temperature will move towards
             !    ! equilibrium, limit the flux as necessary.
             !    tsign = SIGN(1.0d00, dt)
             !    fsign = SIGN(1.0d00, aflux)
             !    IF (tsign .EQ. fsign) THEN
             !       IF (fsign .GT. 0.0) THEN
             !          aflux = MIN(aflux, (dt) /factor)
             !       ELSE 
             !          aflux = MAX(aflux, (dt) /factor)
             !       END IF
             !    ELSE
             !       ! It seems like this should not happen, but it does.
             !       ! aflux = 0.0
             !    END IF
             !    WRITE(*,*) aflux
             ! END IF
             
             flux = flux + aflux

             ! This tortured logic is to fix temperature range
             ! problems caused by atmospheric exchange (e.g. really
             ! small volumes), and NOT fix transport errors that may
             ! have occured elsewhere.

             dt = factor*flux
             
             t = tout + dt
             IF (this%do_limit) THEN
                IF (t .GE. temperature_max) THEN
                   IF (tout .GE. temperature_max) THEN
                      t = tout
                   ELSE
                      t = temperature_max
                   END IF
                END IF
                IF (t .LT. temperature_min) THEN
                   IF (tout .LT. temperature_min) THEN
                      t = tout
                   ELSE
                      t = temperature_min
                   END IF
                END IF
             END IF
             tout = t
          END IF
       END IF
    END IF
  END FUNCTION temperature_source

  ! ----------------------------------------------------------------
  !  FUNCTION new_tdg
  ! ----------------------------------------------------------------
  FUNCTION new_tdg(dometric, dodiff, dolatq, dosrc) RESULT(t)

    IMPLICIT NONE
    TYPE (tdg) :: t
    LOGICAL, INTENT(IN) :: dometric, dodiff, dolatq, dosrc

    t%dometric = dometric
    t%dodiffusion = dodiff
    t%dolatinflow = dolatq
    t%dosource = dosrc
    t%bctype = TRANS_BC_TYPE

    t%needmet = t%dosource

  END FUNCTION new_tdg

  ! ----------------------------------------------------------------
  ! SUBROUTINE tdg_output
  ! ----------------------------------------------------------------
  SUBROUTINE tdg_output(this, ispec, pt, cout, nout)

    IMPLICIT NONE
    CLASS(tdg), INTENT(IN) :: this
    INTEGER, INTENT(IN) :: ispec
    CLASS(point_t), INTENT(IN) :: pt
    DOUBLE PRECISION, INTENT(OUT) :: cout(*)
    INTEGER, INTENT(OUT) :: nout

    DOUBLE PRECISION :: cin, twater, salinity, bp

    salinity = 0.0
    
    ! FIXME: Bogus barometric pressure
    bp = 760.0

    nout = 3
    cout(1:nout) = 0.0
    cin = pt%trans%cnow(ispec)
    twater = pt%trans%twater
    IF (cin > 0.0) THEN
       cout(1) = cin
       cout(2) = TDGasSaturation(cin, twater, salinity, bp)
       cout(3) = TDGasPress(cin, twater, salinity)
    END IF
  END SUBROUTINE tdg_output


  ! ----------------------------------------------------------------
  !  FUNCTION tdg_source
  ! ----------------------------------------------------------------
  FUNCTION tdg_source(this, cin, pt, deltat, met) RESULT (cout)

    IMPLICIT NONE
    DOUBLE PRECISION :: cout
    CLASS(tdg), INTENT(IN) :: this
    TYPE (point_transport_state), INTENT(INOUT) :: pt
    DOUBLE PRECISION, INTENT(IN) :: cin, deltat
    CLASS (met_zone_t), INTENT(INOUT), POINTER :: met

    DOUBLE PRECISION :: area, width, twater, salinity

    cout = this%scalar_t%source(cin, pt, deltat, met)
    
    IF (this%dosource) THEN
       IF (ASSOCIATED(met)) THEN
          area = pt%xsprop%area
          width = pt%xsprop%topwidth
          twater = pt%twater
          salinity = 0.0
          IF (area .GT. 0.0) THEN
             cout = cout + met%gas_exchange(twater, cout, salinity)*deltat*width/area
          END IF
       END IF
    END IF
  END FUNCTION tdg_source

  ! ----------------------------------------------------------------
  ! SUBROUTINE scalar_manager_init
  ! ----------------------------------------------------------------
  SUBROUTINE scalar_manager_init(this, cfg)

    IMPLICIT NONE
    CLASS (scalar_manager), INTENT(INOUT) :: this
    TYPE (configuration_t), INTENT(IN) :: cfg

    INTEGER :: i

    this%temp_index = 0
    this%nspecies = 0

    IF (cfg%do_transport) THEN
       IF (cfg%do_gas .AND. cfg%do_temp) THEN
          this%nspecies = 2
       ELSE
          this%nspecies = 1
       END IF

       ALLOCATE(this%species(this%nspecies))
       DO i = 1, this%nspecies
          NULLIFY(this%species(i)%p)
       END DO
       i = 1
       IF (cfg%do_gas) THEN
          ALLOCATE(this%species(i)%p, &
               &SOURCE=tdg((cfg%units .EQ. METRIC_UNITS), &
               &           cfg%gas_diffusion, &
               &           cfg%do_latflow, cfg%gas_exchange))
          i = i + 1
       END IF
       IF (cfg%do_temp) THEN
          ALLOCATE(this%species(i)%p, &
               &SOURCE=temperature((cfg%units .EQ. METRIC_UNITS), &
               &                    cfg%temp_diffusion, &
               &                    cfg%do_latflow, cfg%temp_exchange, &
               &                    cfg%do_temp_frict, cfg%do_temp_bed))
          this%temp_index = i
          i = i + 1
       END IF
    END IF
       
  END SUBROUTINE scalar_manager_init


END MODULE scalar_module


