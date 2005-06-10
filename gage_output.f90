
!***************************************************************
!            Pacific Northwest National Laboratory
!***************************************************************
!
! NAME: gage_output
!
! VERSION and DATE: MASS1 v0.61 11/21/1997
!
! PURPOSE: prints a time-series file for gage location
!
! RETURNS:
!
! REQUIRED:
!
! LOCAL VARIABLES:
!
! COMMENTS:
!
!
! MOD HISTORY: added hyd_radius, friction_slope, etc.; mcr 11/21/1997
!
!
!***************************************************************
!

SUBROUTINE gage_output

USE utility
USE link_vars
USE general_vars
USE point_vars
USE file_vars
USE transport_vars
USE date_vars

USE scalars
USE met_data_module
USE gas_functions
USE logicals, ONLY : file_exist, do_temp, do_gas, temp_exchange, gas_exchange

USE hydro_output_module
USE accumulator
USE date_time

IMPLICIT NONE

CHARACTER(LEN=80), SAVE :: RCS_ID = "$Id$"


REAL :: depth, tdg_sat, tdg_press
DOUBLE PRECISION :: salinity = 0.0
INTEGER :: i,link,point,count=0
INTEGER, SAVE :: num_gages
INTEGER, SAVE :: gage_link(500),gage_point(500)
INTEGER :: len1,len2,spot1,spot2
CHARACTER*20 fname,string1,string2
        
IF(time == time_begin )THEN
    count=0
    CALL open_existing(filename(14), fileunit(14), fatal=.TRUE.)

    DO WHILE(.TRUE.)
    count=count+1   
    READ(fileunit(14),*, END=100)gage_link(count),gage_point(count)
    END DO
100     CLOSE(fileunit(14))
    IF (count .gt. 0) count = count - 1
    num_gages=count
    DO i=1,num_gages
    count = 50 + i
        fname = ''
    fname(1:2) = 'ts'
    WRITE(string1,*)gage_link(i)
    WRITE(string2,*)gage_point(i)
    !READ(gage_point(i),*)string2
    string1 = ADJUSTL(string1)
    string2 = ADJUSTL(string2)
    len1 = LEN_TRIM(string1)
    len2 = LEN_TRIM(string2)
    spot1 =3 + len1 - 1
    fname(3:spot1) = string1(1:len1)
    spot1 = spot1 + 1
    spot2 = spot1 + len2 - 1
    fname(spot1:spot2) = string2(1:len2)
    spot1 = spot2 + 1
    spot2 = spot1 + LEN_TRIM('.out')
    fname(spot1:spot2) = '.out'
    OPEN(count,file=fname)
    !WRITE(count,1005)'date','time','water el','discharge','velocity','depth ', &
    ! 'conc ','temp ','thalweg el ','area ','top width ','hyd radius ','Froude Num ','frict slope ', &
    ! 'bed shear '
!1005 FORMAT(2a7,20a12)
    WRITE(count,1005)
1005 FORMAT('#',1x,'date',8x,'time',5x,'water elev',2x,'discharge',5x,'vel',4x,'depth', &
     7x,'conc',4x,'temp' ,2x,'%Sat',3x,'TDG P', &
        4x,'thalweg el',2x,'area ',2x,'top width',2x,'hyd rad',2x,'Fr #',2x,'frict slope', &
        2x,'bed shear')

    END DO

    CALL hydro_output_setup()

ENDIF

DO i=1,num_gages
count = 50 + i

link = gage_link(i)
point = gage_point(i)
depth = accum_var%y%sum(link,point) - thalweg(link,point)
IF( (do_temp .AND. temp_exchange) .OR. (do_gas .AND. gas_exchange) ) &
     &CALL update_met_data(time, met_zone(link))
tdg_sat =   TDGasSaturation( DBLE(species(1)%conc(link,point)), DBLE(species(2)%conc(link,point)), salinity, baro_press)
tdg_press = TDGasPress( DBLE(species(1)%conc(link,point)), DBLE(species(2)%conc(link,point)), salinity)

CALL decimal_to_date(accum_time, date_string, time_string)

!!$WRITE(count,1010)date_string,time_string,y(link,point),q(link,point),vel(link,point),depth, &
!!$     species(1)%conc(link,point),species(2)%conc(link,point), tdg_sat, tdg_press, &
!!$     thalweg(link,point),area(link,point),top_width(link,point),hyd_radius(link,point), &
!!$     froude_num(link,point),friction_slope(link,point),bed_shear(link,point)
WRITE(count,1010)date_string,time_string,&
     &accum_var%y%sum(link,point),accum_var%q%sum(link,point),&
     &accum_var%vel%sum(link,point),depth, &
     &accum_var%conc(1)%sum(link,point),accum_var%conc(2)%sum(link,point), &
     &accum_var%tdg%sat%sum(link,point), accum_var%tdg%press%sum(link,point), &
     &thalweg(link,point),accum_var%area%sum(link,point),&
               &accum_var%top_width%sum(link,point),&
               &accum_var%hyd_radius%sum(link,point),&
               &accum_var%froude_num%sum(link,point),&
               &accum_var%friction_slope%sum(link,point),&
               &accum_var%bed_shear%sum(link,point)
!WRITE(count,1010)date_string,time_string,y(link,point),q(link,point),vel(link,point),depth, &
!     c(link,point),temp(link,point),thalweg(link,point),area(link,point)


1010 FORMAT(a10,2x,a8,2x,f8.2,2x,f12.2,2x,f6.2,2x,f7.2,2x,f10.2,2x,f6.2,2x,f6.2,2x,f6.1,2x, &
            f8.2,2x,es10.2,2x, &
            f8.2,2x,f6.2,f6.2,es10.2,2x,es10.2)

!WRITE(count,1000)time/time_mult,q(link,point),y(link,point),depth,vel(link,point),c(link,point),temp(link,point)

1000   FORMAT(6f10.2,11f12.6)

END DO

IF (time > time_begin) CALL hydro_output(date_string,time_string)

IF(time >= time_end)THEN

    DO i=1,num_gages
    count = 50 + i
    CLOSE(count)
    END DO

    CALL hydro_output_done()
ENDIF

END SUBROUTINE gage_output
