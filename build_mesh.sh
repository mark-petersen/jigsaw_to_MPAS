#!/usr/bin/env bash
# Directs process to build MPAS mesh using JIGSAW
# Mark R Petersen and Phillip J Wolfram, 01/19/2018
# Last updated 4/20/2018

# user defined commands and paths:
MATLAB='matlab -nodesktop -nodisplay -nosplash -r '
MPASTOOLS='path/to/repo/MPAS-Tools'
JIGSAW='path/to/repo/jigsaw-geo-matlab'

# Mark's paths on grizzly, LANL IC
MPASTOOLS='/usr/projects/climate/mpeterse/repos/MPAS-Tools/jigsaw_to_MPAS'
JIGSAW='/usr/projects/climate/mpeterse/repos/jigsaw-geo-matlab/master'
MATLAB='octave --silent --eval '

# fill in longer paths, based on paths above:
JIGSAW2NETCDF=$MPASTOOLS/grid_gen/triangle_jigsaw_to_netcdf/
MESHCONVERTER=$MPASTOOLS/grid_gen/mesh_conversion_tools/MpasMeshConverter.x
CELLCULLER=$MPASTOOLS/grid_gen/mesh_conversion_tools/MpasCellCuller.x
VTKEXTRACTOR=$MPASTOOLS/python_scripts/paraview_vtk_field_extractor/paraview_vtk_field_extractor.py

# First argument to this shell script is the name of the mesh
MESHNAME=$1
if [ -f define_mesh/${MESHNAME}.m ]; then
   echo "Starting workflow to build mesh from ${MESHNAME}.m"
else
   echo "File define_mesh/${MESHNAME}.m does not exist."
	 echo "call using:"
	 echo "   build_mesh.sh meshname"
	 echo "where meshname is from define_mesh/*.m, as follows:"
	 ls define_mesh
	 exit
fi

echo
echo 'Step 1. Build mesh using JIGSAW ...'
echo $MATLAB "driver_jigsaw_to_mpas('$MESHNAME')"
echo
$MATLAB "driver_jigsaw_to_mpas('$MESHNAME','$JIGSAW')"
echo 'done'
echo
echo 'Step 2. Convert triangles from jigsaw format to netcdf...'
cd generated_meshes/$MESHNAME
echo "triangle_jigsaw_to_netcdf.py -s -m ${MESHNAME}-MESH.msh -o ${MESHNAME}_triangles.nc"
$JIGSAW2NETCDF/triangle_jigsaw_to_netcdf.py -s -m ${MESHNAME}-MESH.msh -o ${MESHNAME}_triangles.nc
echo 'done'
echo
echo 'Step 3. Convert from triangles to MPAS mesh...'
echo "MpasMeshConverter.x ${MESHNAME}_triangles.nc ${MESHNAME}_base_mesh.nc"
$MESHCONVERTER ${MESHNAME}_triangles.nc ${MESHNAME}_base_mesh.nc
echo 'Injecting bathymetry ...'
ln -isf $JIGSAW/jigsaw/geo/topo.msh .
echo "inject_bathymetry.py ${MESHNAME}_base_mesh.nc"
$JIGSAW2NETCDF/inject_bathymetry.py ${MESHNAME}_base_mesh.nc
echo 'done'
echo
echo 'Step 4. (Optional) Create vtk file for visualization'
echo "paraview_vtk_field_extractor.py ${MESHNAME}_base_mesh.nc ${MESHNAME}_vtk"
$VTKEXTRACTOR --ignore_time -d maxEdges=0 -v allOnCells -f  ${MESHNAME}_base_mesh.nc -o ${MESHNAME}_base_mesh_vtk
echo 'done'
echo
echo 'Step 5. (Optional) Cull land cells using topo.msh.  This is a quick cull, not the method for a production mesh.'
echo "MpasCellCuller.x ${MESHNAME}_base_mesh.nc ${MESHNAME}_culled.nc"
$CELLCULLER ${MESHNAME}_base_mesh.nc ${MESHNAME}_culled.nc
echo 'Injecting bathymetry ...'
echo "inject_bathymetry.py ${MESHNAME}_culled.nc"
$JIGSAW2NETCDF/inject_bathymetry.py ${MESHNAME}_culled.nc
echo 'done'
echo
echo 'Step 6. (Optional) Create vtk file for visualization'
echo "paraview_vtk_field_extractor.py ${MESHNAME}_base_mesh.nc ${MESHNAME}_vtk"
$VTKEXTRACTOR --ignore_time -d maxEdges=0 -v allOnCells -f  ${MESHNAME}_culled.nc -o ${MESHNAME}_culled_vtk
echo 'done'
