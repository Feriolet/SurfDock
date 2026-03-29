#!/bin/bash
cat << 'EOF'
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
  ____              __ ____             _      ____       _         __     __            _             
 / ___| _   _ _ __ / _|  _ \  ___   ___| | __ | __ )  ___| |_ __ _  \ \   / /__ _ __ ___(_) ___  _ __  
 \___ \| | | | '__| |_| | | |/ _ \ / __| |/ / |  _ \ / _ \ __/ _` |  \ \ / / _ \ '__/ __| |/ _ \| '_ \ 
  ___) | |_| | |  |  _| |_| | (_) | (__|   <  | |_) |  __/ || (_| |   \ V /  __/ |  \__ \ | (_) | | | | 
 |____/ \__,_|_|  |_| |____/ \___/ \___|_|\_\ |____/ \___|\__\__,_|    \_/ \___|_|  |___/_|\___/|_| |_| 
                                                                                                       
                                                                                                       
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
EOF
                                                                                                       
# This script is used to run SurfDock on test samples
source /opt/conda/bin/activate SurfDock
path=$(readlink -f "$0")
SurfDockdir="$(dirname "$(dirname "$(dirname "$path")")")"
SurfDockdir=${SurfDockdir}
echo SurfDockdir : ${SurfDockdir}

temp="$(dirname "$(dirname "$(dirname "$(dirname "$path")")")")"
model_temp="$(dirname "$(dirname "$(dirname "$path")")")"

#------------------------------------------------------------------------------------------------#
#------------------------------------ Step1 : Setup Params --------------------------------------#
#------------------------------------------------------------------------------------------------#

echo "$(date +"%Y-%m-%d %H:%M:%S")"

export precomputed_arrays="${precomputed_dir}/precomputed/precomputed_arrays"
## Please set the GPU devices you want to use
gpu_string="cpu"
echo "Using CPU device"

## Please set the project name
project_name='SurfDock_easydock'
# /home/caoduanhua/NM_submit_code/SurfDock
# Set default value for target_have_processed if not already set
target_have_processed=${target_have_processed:-false}
## Please set the path to save the surface file and pocket file
surface_out_dir=${temp}/Screen_result/processed_data/${project_name}/easydock_surface
## Please set the path to the input data
data_dir=${SurfDockdir}/data/Screen_sample_dirs/easydock_samples
## Please set the path to the output csv file
out_csv_dir=${temp}/Screen_result/processed_data/${project_name}/input_csv_files/
out_csv_file=${out_csv_dir}/easydock_samples.csv
## Please set the path to the esmbedding file
esmbedding_dir=${temp}/Screen_result/processed_data/${project_name}/test_samples_esmbedding
## Please set the path to the Screen ligand library file
Screen_lib_path=$1

#------------------------------------------------------------------------------------------------#
# -----------------------Step1 : Processed Target Structure -------------------------------------#
#----------------(Set target_have_processed as true if you have done with your pipeline)---------#
#------------------------------------------------------------------------------------------------#

echo "$(date +"%Y-%m-%d %H:%M:%S")"

mkdir -p $surface_out_dir
if [ "$target_have_processed" = true ]; then
  echo "Target structure has been processed, skipping this step."
else
  echo "Processing target structure with OpenBabel..."
  export BABEL_LIBDIR=/opt/conda/envs/SurfDock/lib/openbabel/3.1.0/
  command=`
  python ${SurfDockdir}/comp_surface/protein_process/openbabel_reduce_openbabel.py \
  --data_path ${data_dir} \
  --save_path ${surface_out_dir}`
  state=$command
fi

#------------------------------------------------------------------------------------------------#
#----------------------------- Step2 : Compute Target Surface -----------------------------------#
#------------------------------------------------------------------------------------------------#

echo "$(date +"%Y-%m-%d %H:%M:%S")"

cd $surface_out_dir
command=`
python ${SurfDockdir}/comp_surface/prepare_target/computeTargetMesh_test_samples.py \
--data_dir ${data_dir} \
--out_dir ${surface_out_dir} \
`
state=$command

#------------------------------------------------------------------------------------------------#
#--------------------------------  Step3 : Get Input CSV File -----------------------------------#
#------------------------------------------------------------------------------------------------#

echo "$(date +"%Y-%m-%d %H:%M:%S")"

command=` python \
${SurfDockdir}/inference_utils/construct_csv_input.py \
--data_dir ${data_dir} \
--surface_out_dir ${surface_out_dir} \
--output_csv_file ${out_csv_file} \
--Screen_ligand_library_file ${Screen_lib_path} \
`
state=$command

#------------------------------------------------------------------------------------------------#
#--------------------------------  Step4 : Get Pocket ESM Embedding  ----------------------------#
#------------------------------------------------------------------------------------------------#

echo "$(date +"%Y-%m-%d %H:%M:%S")"
echo "first step"
esm_dir=${SurfDockdir}/esm
sequence_out_file="${esmbedding_dir}/test_samples.fasta"
protein_pocket_csv=${out_csv_file}
full_protein_esm_embedding_dir="${esmbedding_dir}/esm_embedding_output"
pocket_emb_save_dir="${esmbedding_dir}/esm_embedding_pocket_output"
pocket_emb_save_to_single_file="${esmbedding_dir}/esm_embedding_pocket_output_for_train/esm2_3billion_pdbbind_embeddings.pt"
# get faste  sequence
command=`python ${SurfDockdir}/datasets/esm_embedding_preparation.py \
--out_file ${sequence_out_file} \
--protein_ligand_csv ${protein_pocket_csv}`
state=$command
# esm embedding preprateion

full_protein_esm_embedding_check_file=$(python ${SurfDockdir}/bash_scripts/test_scripts/check_esm_embedding.py --esm_embedding_dir ${full_protein_esm_embedding_dir} --sequence_file ${sequence_out_file})

if [ "$full_protein_esm_embedding_check_file" == 'exists' ]; then
  echo "ESM embeddings already exist, skipping this step."
else
  command=`python ${esm_dir}/scripts/extract.py \
  "esm2_t33_650M_UR50D" \
  ${sequence_out_file} \
  ${full_protein_esm_embedding_dir} \
  --repr_layers 33 \
  --include "per_tok" \
  --truncation_seq_length 4096`
  state=$command
fi

echo "third step"
# map pocket esm embedding
command=`python ${SurfDockdir}/datasets/get_pocket_embedding.py \
--protein_pocket_csv ${protein_pocket_csv} \
--embeddings_dir ${full_protein_esm_embedding_dir} \
--pocket_emb_save_dir ${pocket_emb_save_dir}`
state=$command

echo "fourth step"
# save pocket esm embedding to single file 
command=`python ${SurfDockdir}/datasets/esm_pocket_embeddings_to_pt.py \
--esm_embeddings_path ${pocket_emb_save_dir} \
--output_path ${pocket_emb_save_to_single_file}`
state=$command