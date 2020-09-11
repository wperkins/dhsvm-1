# Distributed Hydrology Soil Vegetation Model (DHSVM) 

This repository serves as the public source code repository of the Distributed Hydrology Soil Vegetation Model (DHSVM). You can find DHSVM documentation, and selected past and ongoing DHSVM-based research & projects on the <a href="https://dhsvm.pnnl.gov/">DHSVM website </a>.

DHSVM (<a href="http://onlinelibrary.wiley.com/doi/10.1029/94WR00436/abstract">Wigmosta et al., 1994</a>) numerically represents with high spatial resolution (typically on the order of 100 m) the effects of local weather, topography, soil type, and vegetation on the hydrology within watersheds. The model is used to study the impacts of climate change, land use change, forest management practices, flooding, glacier dynamics, stream temperature and stream quality.

<strong>DHSVM is a research model that does not come with any warrantee or guarantee</strong>. Please be advised that no technical support is available other than the model web page. Because the model is under continous development, there is no guarantee that the newly developed modules or options are exhaustively tested or work properly. 

If you decide to use DHSVM, please acknowledge <a
href="http://onlinelibrary.wiley.com/doi/10.1029/94WR00436/abstract">Wigmosta
et al. [1994]</a> and any other relevant publications. We are very
interested in receiving a copy of any manuscripts of studies in which
the model is used. Finally, if you do find bugs in the model or if you
have improvements to the model code, we are interested in
incorporating your suggestions and/or contributions. 

## DHSVM v 3.2 ##
### _Release date: February 23, 2018_ ###

This is a major release from DHSVM 3.1.2. It includes several new features, function enhancements and bug fixes.<br />
The tutorial and sample data to run DHSVM v 3.2 will be made available on the <a href="https://dhsvm.pnnl.gov/tutorials.stm">DHSVM website </a>.

__New Capabilities__
  * Variable radiation transmittance (with solar position and tree characteristics) 
  * Canopy gap (<a href="https://onlinelibrary.wiley.com/doi/abs/10.1002/hyp.13150">Sun et al., 2018</a>)
  * Snow sliding 
  * Python scripts to create stream network
  * Support of gridded meteorological data input

__Enhancement & Fixes__
  * Negative soil moisture 
  * Configuration and Build with CMake
<br />

# Parallel Version

This branch of DHSVM has been modified to run in parallel using
[Global Arrays](http://hpc.pnl.gov/globalarrays/).  Performance
improvements are documented by
[Perkins et al., 2019](https://doi.org/10.1016/j.envsoft.2019.104533).

## Hydrologic Processes / Options not Implemented in Parallel 

* `Flow Routing` = `UNIT_HYDROGRAPH`

There may be other options that don't work. These are what's known.

## Requirements

In order to build DHSVM, several third party packages are required.  

### Message Passing Interface (MPI)

[MPI](https://en.wikipedia.org/wiki/Message_Passing_Interface) is not
used directly in DHSVM code.  However, an installation is required to
build Global Arrays and build and run DHSVM.  

### Global Arrays

All DHSVM inter-process communication is handled by
[Global Arrays](http://hpc.pnl.gov/globalarrays/).
[Global Arrays](http://hpc.pnl.gov/globalarrays/) essentially provides
a distributed multi-dimensional array data structure.  

### NetCDF

DHSVM can use [NetCDF](https://www.unidata.ucar.edu/software/netcdf/)
for 2D map data input and output. DHSVM can link use the NetCDF
library whether it was built parallel or not.  
Currently,
[NetCDF input format](https://www.unidata.ucar.edu/software/netcdf/docs/netcdf_introduction.html#netcdf_format)
should be HDF5-based NetCDF-4. Map data needs to be arranged in
"north-up" fashion, as binary files are arranged. This means that the
NetCDF y-coordinate must be descending (ascending y is called
"bottom-up"). DHSVM will refuse to read the "bottom-up" arrangement.
[GDAL](https://www.gdal.org/frmt_netcdf.html) utilities can produce
this format using `-co FORMAT=NC4 -co WRITE_BOTTOMUP=NO`. An advantage
of this format is they can be read directly by various GIS systems.

Here is the (abridged) structure of an example DEM NetCDF input file. 

    netcdf rainydem {
    dimensions:
            time = UNLIMITED ; // (1 currently)
            x = 329 ;
            y = 256 ;
    variables:
            double x(x) ;
                    x:standard_name = "projection_x_coordinate" ;
                    x:long_name = "x coordinate of projection" ;
                    x:units = "m" ;
            double y(y) ;
                    y:standard_name = "projection_y_coordinate" ;
                    y:long_name = "y coordinate of projection" ;
                    y:units = "m" ;
            float Basin.DEM(time, y, x) ;
                    Basin.DEM:long_name = "GDAL Band Number 1" ;
                    Basin.DEM:_FillValue = -9999.f ;
                    Basin.DEM:grid_mapping = "transverse_mercator" ;
    }
    
DHSVM can read NetCDF files in two ways: serial and parallel.
"Serial" means that DHSVM reads 2D input files with one process and
distributes the contents to other processes.  This is available even
when the NetCDF library was built to support parallel reads.
"Parallel" means that all processes read the NetCDF files
directly. Parallel NetCDF I/O is a work in progress. It is not helpful
on most systems, but may speed I/O on large clusters that have
parallel file systems (e.g. Lustre).  

To use serial NetCDF, use the following in the DHSVM configuration:

    Format = NETCDF
    
For parallel NetCDF, use

    Format = PNETCDF
    
For the latter, the NetCDF library must be built with the parallel
HDF5 library.  The benefits of parallel NetCDF have not been really
demonstrated yet, but it would probably only be helpful on systems
with parallel file systems (e.g. Lustre).  

### CMake

[CMake](https://cmake.org) provides an automated, cross-platform way
to locate and use system and third-party libraries, and select optional
features.  Version 2.8.12 or greater is required.

## Configuration and Build with CMake 

DHSVM and related utilities can be configured and built using
[CMake](https://cmake.org).  This provides an automated,
cross-platform way to locate and use system libraries (X11,
[NetCDF](http://www.unidata.ucar.edu/software/netcdf/), etc.) and
select optional features.  Here are some terse instructions: 

  * In the top DHSVM (where `CMakeLists.txt` is located), make a
    directory for the build, called `build` maybe.
    
  * In the `build` directory, run [CMake](https://cmake.org) with
    appropriate options, for example,
    
        cmake -D CMAKE_BUILD_TYPE:STRING=Release ..

    Look at `example_configuration.sh` for configurations used on
    several developers' systems. Alternatively, just use the script:

        sh ../example_configuration.sh

    This provides a vanilla configuration without X11,
    [NetCDF](http://www.unidata.ucar.edu/software/netcdf/), or RBM
    using the default C compiler.
    
  * If successful, build DHSVM and related programs, using

        cmake --build .

    The resulting executable programs will be in the build directory
    in a tree mirroring the source tree.  For example, DHSVM is
    `build/DHSVM/sourcecode/DHSVM`. 
    
The original Makefiles are still in the source tree but have not been
maintained.  

### RBM  ###

To build the RBM program, for stream temperature simulation, add 

    -D DHSVM_USE_RBM:BOOL=ON

to the configuration options. 

### Experimental Surface/Subsurface Mode ###

The normal DHSVM surface/subsurface routing scheme uses 4 neighbors
and directs cell outflow to all down-gradient neighbors ("D4").  Another
method, which uses 8 neighbors and directs outflow only to the
neighbor with the steepest gradient ("D8").  The latter has proved useful
in very low-gradient areas that span several cells.  To enable D8
routing add this option

    -D DHSVM_D8:BOOL=ON
    
to the configuration. D4 is the default.  

### Snow-only mode ###

If DHSVM is configured with this option,

    -D DHSVM_SNOW_ONLY:BOOL=ON
   
an additional executable is built, `DHSVM_SNOW`, which operates in
snow-only mode. 

### Timing with GPTL ### 

DHSVM can optionally be compiled to perform some internal timing
during simulations.  This requires the
[General Purpose Timing Library](https://jmrosinski.github.io/GPTL/)
be available on the system.  To enable timing, use the following
configuration options:

    -D DHSVM_USE_GPTL:BOOL=ON 
    -D GPTL_DIR:PATH="/path/to/gptl"
    -D DHSVM_TIMING_LEVEL:STRING="1" 
   
If configured as such, an additional executable, `DHSVM_timed` is
built. `DHSVM_SNOW_timed` will also be built if snow-only mode is
enabled. The resulting executables will produce files named `timing.#` at the
end of simulation, where `#` is the MPI process number.  These contain
timing results for several key simulation components.

The `DHSVM_TIMING_LEVEL` can be from 1 to 4, where 4 produces the most
detailed information.  The timing routines can impact performance with
higher detail, but this is documented in the output.  

### MASS1 Channel Routing ###

DHSVM stream channel routing (not roads) can optionally be performed by the
[Modular Aquatic Simulation System 1D](https://github.com/pnnl/mass1)
(MASS1).  See [MASS1.md](here) for details.

### Build Test Programs ###

A number of programs can be built that test specific parts of DHSVM
code.  These are probably only of interest to the DHSVM developer. By
default, these programs are not built. To enable building the test
programs, add this configuration option:

    -D DHSVM_BUILD_TESTS:BOOL=ON





