# Channel Routing with MASS1 #

DHSVM stream channel routing (not roads) can optionally be performed by the
[Modular Aquatic Simulation System 1D](https://github.com/pnnl/mass1) (MASS1).  

MASS1 is an optional drop-in replacement for DHSVM's channel routing
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
Fortran 2003/2008 constructs. GNU `gfortran` 4.8 and Intel `ifort` 15
are minimum versions of compilers that  have been tested.  

MASS1 is included in DHSVM by using 

```
-D DHSVM_USE_MASS1:BOOL=ON
```
in CMake arguments when configuring.  

## Using MASS1 ##

### Generate a MASS1 Configuration ###

A utility, `channel_mass1`, reads the DHSVM channel class and network
files and prepares a MASS1 configuration. 

#### Prepare a MASS1 Channel State File ####

The MASS1 configuration

#### DHSVM Configuration Language ####

DHSVM built with MASS1 operates just as DHSVM built without MASS1.  In
order to utilize  



