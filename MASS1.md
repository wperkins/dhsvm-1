# Channel Routing with MASS1 #

DHSVM stream channel routing (not roads) can optionally be performed by the
[Modular Aquatic Simulation System 1D](https://github.com/pnnl/mass1) (MASS1).  

MASS1 is an optional, drop-in replacement for DHSVM's channel routing
scheme.  MASS1 not only provides a routing algorithm nearly identical to that
in DHSVM, but also brings several capabilities not
available in DHSVM alone:

 - Hydrodynamic routing using full cross-section averaged St. Venant
   equations.  
 - A large set of prismatic channel section types and a general cross
   section to use actual bathymetry data.
 - Representation of some engineered structures (dams, weirs)
 - Inclusion of channel network segments outside of the basin
   simulated by DHSVM.
 - Conservative tracer transport
 - Water temperature simulation
 
## Building DHSVM with MASS1 ##

MASS1 requires a relatively recent Fortran compiler that understands
Fortran 2003/2008 object-oriented constructs. GNU `gfortran` 4.8 and
Intel `ifort` 15 are minimum versions of compilers that  have been tested.  

MASS1 is included in DHSVM by using 
```
-D DHSVM_USE_MASS1:BOOL=ON
```
in CMake arguments when configuring.  MASS1 can use OpenMP to perform
routing computations in parallel. To enable OpenMP, specify
```
-D DHSVM_ENABLE_OPENMP:BOOL=ON
```
The default is `OFF`. The benefits of using OpenMP with MASS1 are
limited, and it can cause serious performance issues if used
improperly.  It does seem to help DHSVM run times when simulating
large channel networks with a large computational order range.  In
general, it's probably best to leave this off.  

## Using MASS1 ##

MASS1 can be used for stream channel routing, but not road network
routing (yet).  No knowledge of MASS1 is required to simply replace
the internal DHSVM stream routing with MASS1 and simulate stream
temperature.  

### Generate a MASS1 Configuration ###

MASS1 needs to have it's own configuration separate from DHSVM.  A
complete configuration needs generated from DHSVM input files.  A
utility, `channel_mass1`, reads the DHSVM channel class and network
files and prepares a MASS1 configuration.  This configuration can be
used as is, which should result in stream flow very similar
(but not exactly the same) as produced by DHSVM alone.  

It's best to place the MASS1 configuration in its own directory.  

#### Prepare a MASS1 Channel State File ####

Just like the internal DHSVM channel network, the MASS1 network
requires a reasonable initial condition.  

#### DHSVM Configuration Language ####

DHSVM built with MASS1 operates just as DHSVM built without MASS1.  In
order to utilize MASS1 for stream (not road) routing set
```
[OPTIONS]
Flow Routing = MASS1
```
in the  DHSVM input configuration file.  Specify the MASS1
configuration directory produced above using a phrase like
```
[ROUTING]
MASS1 Configuration  = ../mass1
```
The current directory (`.`) is the default. Streamflow output is the same
as DHSVM alone in `Stream.Flow` and `Streamflow.Only`.  

If the stream temperature option is set, i.e.,
```
[OPTIONS]
Stream Temperature   = TRUE
```
then MASS1 will simulate stream temperature, and produce a file named
`Streamtemp.Only` containing simulated temperatures for the same
locations and in the same format as `Streamflow.Only`.  

MASS1 has several coefficients that affect simulated stream
temperature.   They can be specified for each stream segment
individually. The default values for all stream segments are set using
the following phrases in the `[ROUTING]` section shown with default
values: 
```
MASS1 Inflow Temperature = 12.0
MASS1 Wind Function A = 0.46
MASS1 Wind Function B = 9.2
MASS1 Conduction Coefficient = 0.47
MASS1 Brunt Coefficient  = 0.65
MASS1 Internal Longwave = FALSE
MASS1 Use Shading = TRUE
MASS1 Met Coefficient File = none
MASS1 Met Coefficient Output = none
```
The first 5 phrases set the default values for individual stream
segments. In the case where different parts of the stream network have
different coefficients, a separate file can be used to specify those
coefficients for individual segments. Given this phrase
```
MASS1 Met Coefficient File = ../mass1/mass1_met_coeff.dat
```
the file `../mass1/mass1_met_coeff.dat` will contain a record for each
segment that should have different coefficients.  Each record needs to
have the following fields:
   * segment identifier, as listed in the stream network file,
   * wind function a,
   * wind function b,
   * conduction coefficient, 
   * Brunt coefficient, and
   * inflow temperature.
Comments can be proceeded with `#`. Anything on a line after a `#` and
empty lines are ignored.  The contents would look something like this
```
     1     0.46     9.20     0.47     0.65    12.00
     2     0.46     9.20     0.47     0.65    12.00
     3     0.46     9.20     0.47     0.65    12.00
     4     0.46     9.20     0.47     0.65    12.00
     5     0.46     9.20     0.47     0.65    12.00
```
with the default values.  DHSVM first assigns the coefficients in the
configuration file to *all* stream segments. Then, this file is read
and coefficients are updated for *only* those segments listed in the
file.  Optionally, this file can be generated in the output directory
using a phrase like 
```
MASS1 Met Coefficient Output = mass1_met_coeff.dat

```
This is to aid in the case where stream temperature is calibrated for
subbasins then those calibrated coefficients are used in the larger
domain.  

MASS1 gets all necessary meteorologic data from DHSVM.  A couple of
configuration phrases control what MASS1 uses.  By default, MASS1 uses
short- and longwave radiation that is adjusted by topographic, canopy,
and riparian shading (if enabled).  If 
``` 
MASS1 Use Shading = FALSE
``` 
is specified, MASS1 will use incoming short- and longwave
radiation with topographic shading, but ignoring canopy and riparian
shading.

MASS1 can compute incoming longwave radiation internally. This is
typically not necessary, but can be enabled with
```
MASS1 Internal Longwave = FALSE
```
