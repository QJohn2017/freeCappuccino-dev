# freeCappuccino

### This is development version of freeCappuccino, a place for refactoring where a lot of unfinished code will be found.

freeCappuccino is a three-dimensional unstructured finite volume code for Computational Fluid Dynamics which comes in serial and parallel version.

Moreover, freeCappuccino is a fortran library for manipulation of discrete tensor fields, defined over polyhedral meshes.

### Name 'Cappuccino' encapsulates the idea that it is CAFFA (Computer Aided Fluid Flow Analysis) with some FOAM (Field Operation and Manipulation).

freeCappuccino is free both as a free coffee and as free speech.

             MM          MMM
            NMN.           MM
           MMM..   OMM.    MMM.
          .MMO.    MMM      MMM                         ...
          MMM:     MMM      MMM                       .. .?DMD7..
          MMM      MMM      MMM                      ..MMMMMMMMMMM~
          MMM:     .M       MMM.                    .NMMMMMMMMMMMMMM
          .MMM     .M.     .MMM.    ... .?MMMMM .. .MMMMMMMMMMMMMMMMM
           MMM.    .M .    MMM. ....MMMMMMMMMMMM$..MMMMMM?     .7MMMMM.
              MM.  M  M   MM  ..MMMMMMM~.. .MMMMM7MMMMMM.        7MMMMN
                            =MMMMMM7..  ..MMM.MMMMMMMMM+         .MMMMM.
                         DMMMMMD..  . . MMMM. .MMMMMMMM.        ..MMMMM.
                    ..=MMMMMZ.     ...MMMM      MMMMMMMI.        .MMMM$.
                    MMMMM8.   ..  .NMMMM..      :MMMMMMM         :MMMM.
                 :MMMMM.......  ~MMMMN           MMMMMMMMO.      MMMM+
             . ?MMMM:. ....  ,MMMMM              .MMMMMMMMM.    :MMMM.
           ..IMMMM  .  .  =MMMMMI                ..MMMMMMMM.    MMMM=
           .MMMM. .... DMMMMM?                     8MMMMM=     NMMMM
          +MMM.   .~MMMMMM~                        .MMMM.     ,MMMM.
         ~MM?.~MMMMMMM$                              MMMD    .MMMMM
        .DMMMMMMM$                                   MMMM.  .MMMMM
         .MMMM.                                      .MMMN..MMMMM,
         ..MMMM.                                     .MMMM.MMMMMM
           =MMMZ..   .=. ..         ..      =. ,:     .MMMMMMMMM
           .MMMM~..  7  .MM.M   M   MM.    M.  ..  M  .MMMMMMMM+
             MMMM....Z. .MM.M...M...MM..O:.  M . ~.M...ZMMMMMMM
              MMMM,. ., :  ,:   :  :  :    .,  ,,  ,  . MMMMMMM
               MMMM7. ..................................MMMMMM
                MMMM8 ..................................MMMMMM
                 NMMMM  ................................MMMMD
                  7MMMM ............................... MMMM
                    MMMMO............................. :MMM
                     MMMMM..............................MMM
                       MMMMM..........................MMMMM
                        ZMMMMD.......................MMMMM
                          MMMMMM.................. MMMMM
                            MMMMMM. ............OMMMMMZ
                              NMMMMM8.......=MMMMMMMI
                                =MMMMMMMMMMMMMMMMM
                                   NMMMMMMMMMM

Introduction
------------------
The purpose of the code is to enable experimentation in discretizations and mathematical models. Therefore we have included many discretization options and we are in the process of implementation of many turbulence models and scalar equations for different variables.

The code is based on the reference:

N Mirkov, B Rašuo, S Kenjereš, On the improved finite volume procedure for simulation of turbulent flows over real complex terrains, Journal of Computational Physics, Vol. 297 (2015), pp.18-45.

The code allows meshes in OpenFOAM® polyMesh format. Only slight changes are necessary in the 'boundary' file. 

Code provides a utility for converting mashes saved in Gambit .neu format (made in Gambit or in Gmsh and exported as .neu) to native format of freeCappuccino.

Discretized equations are written in CSR (Compressed Sparse Row) format, which allows easy interface with many linear solver libraries, such as [LIS](http://www.ssisc.org/lis/). Also, one can use linear solvers provided in the code such as, Incomplete Cholesky Conjugate Gradient (ICCG), ILU(0) preconditioned Bi-Conjugate Gradient Stabilised method for non-symmetric systems, etc.

Requirements
-----------------
The code is written in modern fortran, so you will need fortran compiler (e.g. gfortran). Code may be built to use external library for solution of sparse linear systems [LIS](http://www.ssisc.org/lis/) or be used without it, just using built in linear solvers.

Getting started
-----------------
Clone the git repository or download the zip archive of the most recent source, compile and build the code, and checkout the examples such as the lid-driven cavity, Pitz-Daily backward facing step, channel, and many more to come.

License
------------------
The code is published under GNU General Public License v3.0.


Tribute section
------------------

This section tributes some open source CFD developers

![alt tag](https://github.com/nikola-m/freeCappuccino/blob/master/doc/cluster.jpg)

Andrei Chernousov and his cluster circa 2001.

![alt tag](https://github.com/nikola-m/freeCappuccino/blob/master/doc/henry%20and%20papers.png)

Henry Weller and writing papers.

