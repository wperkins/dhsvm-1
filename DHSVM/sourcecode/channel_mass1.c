/*
 * SUMMARY:      channel_mass1.c
 * USAGE:        Part of DHSVM
 *
 * AUTHOR:       William A. Perkins
 * ORG:          Pacific NW National Laboratory
 * E-MAIL:       william.perkins@pnnl.gov
 * ORIG-DATE:    June 2017
 * DESCRIPTION:  Reads a DHSVM stream network and makes an equivalent
 *               MASS1 network and configuration.
 *
 * DESCRIP-END.cd
 * FUNCTIONS:    
 * LAST CHANGE: 2019-05-29 11:56:30 d3g096
 * COMMENTS:
 */


#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <libgen.h>
#include <string.h>
#include <sys/param.h>
#include <math.h>

#include "errorhandler.h"
#include "channel.h"

/******************************************************************************/
/*                             channel_compute_elevation                      */
/******************************************************************************/
void
channel_compute_elevation(Channel *network, float elev0)
{
  Channel *current = NULL;
  int max_order, o;

  max_order = 0;
  for (current = network; current != NULL; current = current->next) {
    if (current->order > max_order) max_order = current->order;
  }

  error_handler(ERRHDL_DEBUG, "computing channel elevations (maxorder = %d)",
                max_order);

  for (o = max_order; o > 0; --o) {
    for (current = network; current != NULL; current = current->next) {
      if (current->order == o) {
        if (current->outlet) {
          current->outlet_elevation = current->outlet->inlet_elevation;
        } else {
          current->outlet_elevation = elev0;
        }
        current->inlet_elevation = current->outlet_elevation + 
          current->length*current->slope;
      }
    }
  }
}

/******************************************************************************/
/*                             channel_points                                 */
/******************************************************************************/
static int
channel_points(const float length, const float spacing)
{
  int npts = (int)truncf(length/spacing + 1.0);
  if (npts < 2) npts = 2;
  npts = 2;                     /* hydrologic links can (now) only have 2 points */
  return npts;
}

/******************************************************************************/
/*                           mass1_write_config                               */
/******************************************************************************/
void
mass1_write_config(const char *outname)
{
  const char cfg[] =
    "    MASS1 Configuration File - Version 0.83\n"
    "0	/	Do Flow\n"
    "0	/	Do lateral inflow\n"
    "0	/	Do Gas\n"
    "0	/	Do Temp\n"
    "0	/	Do Printout\n"
    "1	/	Do Gage Printout\n"
    "0	/	Do Profile Printout\n"
    "0	/	Do Gas Dispersion\n"
    "0	/	Do Gas Air/Water Exchange\n"
    "0	/	Do Temp Dispersion\n"
    "0	/	Do Temp surface exchange\n"
    "0	/	Do Hotstart read file\n"
    "1	/	Do Restart write file\n"
    "0	/	Do Print section geometry\n"
    "0	/	Do write binary section geom\n"
    "0	/	Do read binary section geom\n"
    "1	/	units option\n"
    "1	/	time option\n"
    "2	/	time units\n"
    "1	/	channel length units\n"
    "0	/	downstream bc type\n"
    "5	/	max links\n"
    "400	/ max points on a link\n"
    "28	/	max bc table\n"
    "60000	/	max times in a bc table\n"
    "1379	/	total number of x-sections\n"
    "0          /   number of transport sub time steps\n"
    "0 	/	debug print flag\n"
    "\"%slink.dat\" / link file name\n"
    "\"%spoint.dat\" / point file name nonuniform manning n\n"
    "\"%ssection.dat\" / section file name\n"
    "\"%sbc.dat\"	/ linkBC file name\n"
    "\"%sinitial.dat\"      / initial file name\n"
    "\"output.out\"            / output file name\n"
    "\"none\"	/ gas transport file name\n"
    "\"none\"   / temperature input\n"
    "\"none\" / weather data files for each met_zone input\n"
    "\"none\" /	hydropower file name\n"
    "\"none\" 	/	TDG Coeff file name\n"
    "\"none\" 	/	hotstart-warmup-unix.dat /	read restart file name\n"
    "\"hotstart.dat\"          / Write restart file name\n"
    "\"%sgage.dat\"         / gage control file name\n"
    "\"none\" 	 	/	profile file name\n"
    "\"none\"     		/	lateral inflow bs file name\n"
    "02-01-2000	/	date run begins\n"
    "00:00:00	/	time run begins\n"
    "01-10-2001	/	date run ends\n"
    "00:00:00	/	time run ends\n"
    "0.5	/	delta t in hours (0.5 for flow only; 0.02 for transport)\n"
    "336	/	printout frequency\n";

  static char outfile[] = "mass1.cfg";
  FILE *out;
  if ((out = fopen(outfile, "wt")) == NULL) {
    error_handler(ERRHDL_ERROR, "cannot open configuration file \"%s\"",
                  outfile);
    return;
  }

  error_handler(ERRHDL_DEBUG, "writing MASS1 configuration to \"%s\"",
                outfile);

  fprintf(out, cfg,
          outname, outname, outname, outname, outname, outname);
  fclose(out);
}
  
  

/******************************************************************************/
/*                           mass1_write_sections                             */
/******************************************************************************/
void
mass1_write_sections(const char *outname, ChannelClass *classes)
{
  ChannelClass *current;
  char outfile[MAXPATHLEN];
  FILE *out;
  float width;
  
  sprintf(outfile, "%ssection.dat", outname);
  if ((out = fopen(outfile, "wt")) == NULL) {
    error_handler(ERRHDL_ERROR, "cannot open section file \"%s\"",
                  outfile);
    return;
  }

  error_handler(ERRHDL_DEBUG, "writing MASS1 cross sections to \"%s\"",
                outfile);

  for (current = classes; current != NULL; current = current->next) {
    fprintf(out, "%d     1\n%.2f /\n", current->id, current->width);
  }

  fclose(out);
}

/******************************************************************************/
/*                          mass1_write_links                                 */
/******************************************************************************/
void
mass1_write_links(const char *outname, Channel *network, const float spacing)
{
  char outfile[MAXPATHLEN];
  FILE *out;
  Channel *current;

  sprintf(outfile, "%slink.dat", outname);
  if ((out = fopen(outfile, "wt")) == NULL) {
    error_handler(ERRHDL_ERROR, "cannot open link file \"%s\"",
                  outfile);
    return;
  }

  error_handler(ERRHDL_DEBUG, "writing MASS1 link information to \"%s\"",
                outfile);

  for (current = network; current != NULL; current = current->next) {
    int npts;
    npts = channel_points(current->length, spacing);

    fprintf(out, "%5d", current->id); 
    fprintf(out, " %5d", 2);              /* input option */
    fprintf(out, " %5d", npts);           /* number of points */
    fprintf(out, " %5d", current->order); /* link order (unused) */
    fprintf(out, " %5d", 60);             /* link type */
    fprintf(out, " %5d", 0);              /* upstream links (unused) */

                                          /* upstream BC */
    if (current->order > 1) {
      fprintf(out, " %5d", 0);
    } else {
      fprintf(out, " %5d", 1);
    }
                                          /* downstream BC */
    if (current->outlet == NULL) {
      fprintf(out, " %5d", 2);
    } else {
      fprintf(out, " %5d", 0);
    }
    
    fprintf(out, " %5d", 0);              /* TDG BC */
    fprintf(out, " %5d", 0);              /* temperature BC */
    fprintf(out, " %5d", current->id);    /* met zone */
                                          /* lateral inflow, TDG, temp BC */
    fprintf(out, " %5d %5d %5d", 0, 0, 0);
    fprintf(out, " %5.1f", 3.5);          /* LPI coefficient */

    fprintf(out, " /\n");

    if (current->outlet == NULL) {
      fprintf(out, "%5d", 0);
    } else {
      fprintf(out, "%5d", current->outlet->id); 
    }
    fprintf(out, "%78.78s /\n", " ");
  }
  fclose(out);
}

/******************************************************************************/
/*                           mass1_write_points                               */
/******************************************************************************/
void
mass1_write_points(const char *outname, Channel *network, const float spacing)
{
  char outfile[MAXPATHLEN];
  FILE *out;
  Channel *current;

  sprintf(outfile, "%spoint.dat", outname);
  if ((out = fopen(outfile, "wt")) == NULL) {
    error_handler(ERRHDL_ERROR, "cannot open point file \"%s\"",
                  outfile);
    return;
  }

  error_handler(ERRHDL_DEBUG, "writing MASS1 point information to \"%s\"",
                outfile);

  for (current = network; current != NULL; current = current->next) {
    int npts;
    npts = channel_points(current->length, spacing);

    fprintf(out, "%5d", current->id);                   /* link id */
    fprintf(out, " %10.2f", current->length);           /* link length */
    fprintf(out, " %10.2f", current->inlet_elevation);  /* upstream elevation */
    fprintf(out, " %10.2f", current->outlet_elevation); /* downstream elevation */
    fprintf(out, " %5d", current->class2->id);          /* section id */
    fprintf(out, " %10.4f", current->class2->friction); /* Manning's n */
    fprintf(out, " %10.1f", 300.0);                     /* longitudinal dispersion */
    fprintf(out, " %10.4f", 0.0);                       /* unused */
    fprintf(out, " /\n");
  }
  fclose(out);
}

/******************************************************************************/
/*                            mass1_write_bcs                                 */
/******************************************************************************/
void
mass1_write_bcs(const char *outname, Channel *network)
{
  char outfile[MAXPATHLEN];
  FILE *out;
  Channel *current;

  static char zerofile[] = "zero.dat";
  static char zerobc[] =
    "#\n"
    "01-01-1900 00:00:00 0.0 /\n"
    "01-01-2900 00:00:00 0.0 /\n";

  if ((out = fopen(zerofile, "wt")) == NULL) {
    error_handler(ERRHDL_ERROR, "cannot open BC file \"%s\"",
                  outfile);
    return;
  }
  fprintf(out, zerobc);
  fclose(out);

  sprintf(outfile, "%sbc.dat", outname);
  if ((out = fopen(outfile, "wt")) == NULL) {
    error_handler(ERRHDL_ERROR, "cannot open link BC file \"%s\"",
                  outfile);
    return;
  }
  fprintf(out, "1 \"%s\" /\n", zerofile);
  fclose(out);
}

/******************************************************************************/
/*                         mass1_write_initial                                */
/******************************************************************************/
void
mass1_write_initial(const char *outname, Channel *network, const int dodry)
{
  char outfile[MAXPATHLEN];
  FILE *out;
  Channel *current;
  float wsel;
  
  sprintf(outfile, "%sinitial.dat", outname);
  if ((out = fopen(outfile, "wt")) == NULL) {
    error_handler(ERRHDL_ERROR, "cannot open point file \"%s\"",
                  outfile);
    return;
  }

  error_handler(ERRHDL_DEBUG, "writing MASS1 initial state information to \"%s\"",
                outfile);

  

  for (current = network; current != NULL; current = current->next) {

    /* set the water surface elevation to bank_height at the
       upstream end of the segment */
    
    wsel = current->inlet_elevation + current->class2->bank_height;
    fprintf(out, "%8d %10.1f %10.1f %10.1f %10.1f /\n", current->id,
            1.0, wsel, 0.0, 10.0);
  }
  fclose(out);
}


/******************************************************************************/
/*                            Main Program                                    */
/******************************************************************************/
int
main(int argc, char **argv)
{
  char *program;
  char ch;
  char class_file[MAXPATHLEN], network_file[MAXPATHLEN];
  char outname[MAXPATHLEN];
  ChannelClass *classes, *c;
  Channel *network, *l;
  int n, ierr;
  int maxid;
  float spacing;
  float elev0;

  const char usage[] = "usage: %s [-v] [-s spacing] [-o basename] class.dat network.dat";

  program = basename(argv[0]);

  error_handler_init(program, NULL, ERRHDL_MESSAGE);

  strncpy(outname, "", MAXPATHLEN);
  spacing = 250.0;
  elev0 = 0.0;
  ierr = 0;

  while ((ch = getopt(argc, argv, "vs:o:")) != -1) {
    switch (ch) {
    case 'v': 
      error_handler_init(program, NULL, ERRHDL_DEBUG);
      break;
    case 's':
      spacing = strtof(optarg, NULL);
      if (spacing <= 0.0) {
        error_handler(ERRHDL_ERROR, "spacing \"%s\" not understood", optarg);
        ierr++;
      }
      break;
    case 'o':
      strncpy(outname, optarg, MAXPATHLEN);
      break;
    default:
      error_handler(ERRHDL_FATAL, usage, program);
      exit(3);
    }
  }
  argc -= optind;
  argv += optind;

  if (argc < 2) {
    error_handler(ERRHDL_FATAL, usage, program);
    exit(2);
  } else {
    strncpy(class_file, argv[0], MAXPATHLEN);
    strncpy(network_file, argv[1], MAXPATHLEN);
  }

  error_handler(ERRHDL_DEBUG, "nominal section spacing = %.1f", spacing);
  error_handler(ERRHDL_DEBUG, "reading channel classes from %s...",
                class_file);
  classes = channel_read_classes(class_file, 0);
  c = classes;
  n = 0;
  while (c != NULL) {
    ++n;
    c = c->next;
  }
  error_handler(ERRHDL_DEBUG, "%d channel classes read.", n);


  error_handler(ERRHDL_DEBUG, "reading channel segments from %s...",
                network_file);
  network = channel_read_network(network_file, classes, &maxid);
  l = network;
  n = 0;
  while (l != NULL) {
      ++n;
      l = l->next;
  }
  error_handler(ERRHDL_DEBUG, "%d channel segments read.", n);

  channel_compute_elevation(network, elev0);

  mass1_write_config(outname);
  mass1_write_sections(outname, classes);
  mass1_write_links(outname, network, spacing);
  mass1_write_points(outname, network, spacing);
  mass1_write_initial(outname, network, 0);

  channel_free_network(network);
  channel_free_classes(classes);
  
  error_handler_done();
}
