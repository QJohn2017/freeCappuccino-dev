#
# Makefile for caffa3d program
#

# Compiler flags:
LFLAGS = -llapack
F90FLAGS = -Wall -O2

# L95FLAGS = -fopenmp -llis -llapack
# F95FLAGS = -Wall -O2 -cpp

# LIS_DIR = /usr/local/include 

# Compiler:
F90 = mpif90

MOD_FILES=\
    modules_allocatable.f90 \
    utils.f90 \
    matrix.f90 \
    geometry.f90 \
    tensor_fields.f90 \
    field_initialization.f90 \
    sparse_matrix.f90 \
    gradients.f90 \
    output.f90 \
    interpolation.f90 \
    scalar_fluxes.f90

MPI_FILES=\
    global_max_mpi.f90 \
    global_min_mpi.f90 \
    global_sum_mpi.f90 \
    global_isum_mpi.f90 \
    abort_mission_mpi.f90 \
    synchronize_mpi.f90 \
    exchange.f90

LINEAR_SOLVER_FILES=\
    iccg.f90 \
    bicgstab.f90 \
    dpcg.f90 \
    jacobi.f90 \
    mgmres.f90

TURBULENCE_FILES=\
    temperature.f90 \
    concentration.f90 \
    k_epsilon_std.f90 \
    k_omega_sst.f90 \
    k_epsilon_rng.f90 \
    spalart_allmaras.f90 \
    k_eqn_eddy.f90
#     k_epsilon_zeta_f.f90

CAFFA_FILES=\
    allocate.f90 \
    asm_stress_terms.f90 \
    asm_heatflux_terms.f90 \
    adjustMassFlow.f90 \
    bcin.f90 \
    bpres.f90 \
    fieldManipulation.f90 \
    faceflux_velocity.f90 \
    faceflux_mass.f90 \
    calcheatflux.f90 \
    calcp_simple.f90 \
    calcp_piso.f90\
    calcstress.f90 \
    calc_strain_and_vorticity.f90 \
    calcuvw.f90 \
    calc_statistics.f90 \
    CourantNo.f90 \
    updateVelocityAtBoundary.f90 \
    correct_turbulence.f90 \
    correct_turbulence_inlet.f90 \
    continuityErrors.f90\
    constant_mass_flow_forcing.f90 \
    recirculate_flow.f90 \
    fvm_laplacian.f90 \
    init.f90 \
    readfiles.f90 \
    read_input.f90 \
    random_seed.f90 \
    time_shift.f90 \
    vortexIdentification.f90\
    writefiles.f90 \
    write_restart_files.f90 \
    writehistory.f90 \
    main.f90 


POISSON_FILES=\
    fvm_laplacian.f90 \
    poisson.f90

#
# How to create object files:
# 
MODS = ${MOD_FILES:.f90=.o}
MPI = ${MPI_FILES:.f90=.o}
TURBULENCE = ${TURBULENCE_FILES:.f90=.o}
LINEAR_SOLVERS = ${LINEAR_SOLVER_FILES:.f90=.o}
CAFFAOBJS = ${CAFFA_FILES:.f90=.o}
POISSONOBJS = ${POISSON_FILES:.f90=.o}

##################################################################
# Targets for make.
##################################################################

all: cappuccino-mpi poisson-mpi

cappuccino-mpi: ${MODS} ${MPI} ${TURBULENCE} ${LINEAR_SOLVERS} ${CAFFAOBJS}
	@echo  "Linking" $@ "... "
	${F90} ${CAFFAOBJS} ${MODS} ${MPI} ${TURBULENCE} ${LINEAR_SOLVERS} ${LFLAGS} ${INCS} -o ../bin/cappuccino-mpi 

poisson-mpi: ${MODS} ${MPI} ${LINEAR_SOLVERS} ${POISSONOBJS}
	@echo  "Linking" $@ "... "
	${F90} ${POISSONOBJS} ${MODS} ${MPI} ${LINEAR_SOLVERS} ${LFLAGS} ${INCS} -o ../bin/poisson-mpi

.PHONY: clean
clean:
	@rm  *.o *.mod ../bin/cappuccino-mpi ../bin/poisson-mpi

##################################################################
# Generic rules
##################################################################

.SUFFIXES : .f90 .f95

.f90.o:
	${F90} ${F90FLAGS} -c ${INCS}  ${@:.o=.f90}

.f95.o:
	${F90} ${F95FLAGS} -I${LIS_DIR} -c ${INCS}  ${@:.o=.f95}
