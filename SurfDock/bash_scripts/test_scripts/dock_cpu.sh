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
## Please set the path to the docking result directory
docking_out_dir=$2

#------------------------------------------------------------------------------------------------#
#------------------------  Step5 : Start Sampling Ligand Confromers  ----------------------------#
#------------------------------------------------------------------------------------------------#

echo "$(date +"%Y-%m-%d %H:%M:%S")"
pocket_emb_save_dir="${esmbedding_dir}/esm_embedding_pocket_output"
pocket_emb_save_to_single_file="${esmbedding_dir}/esm_embedding_pocket_output_for_train/esm2_3billion_pdbbind_embeddings.pt"

diffusion_model_dir=${model_temp}/model_weights/docking
confidence_model_base_dir=${model_temp}/model_weights/posepredict
protein_embedding=${pocket_emb_save_to_single_file}
test_data_csv=${out_csv_file}
cd ${SurfDockdir}/bash_scripts/test_scripts
mdn_dist_threshold_test=3.0
version=6
dist_arrays=(3)
for i in ${dist_arrays[@]}
do
mdn_dist_threshold_test=${i}

command=`python \
${SurfDockdir}/inference_accelerate.py \
--data_csv ${test_data_csv} \
--model_dir ${diffusion_model_dir} \
--ckpt best_ema_inference_epoch_model.pt \
--confidence_model_dir ${confidence_model_base_dir} \
--confidence_ckpt best_model.pt \
--save_docking_result \
--mdn_dist_threshold_test ${mdn_dist_threshold_test} \
--esm_embeddings_path ${protein_embedding} \
--run_name ${confidence_model_base_dir}_test_dist_${mdn_dist_threshold_test} \
--project ${project_name} \
--out_dir ${docking_out_dir} \
--batch_size 400 \
--batch_size_molecule 10 \
--samples_per_complex 3 \
--save_docking_result_number 3 \
--head_index  0 \
--tail_index 10000 \
--inference_mode Screen \
--wandb_dir ${temp}/docking_result/test_workdir`
state=$command
done
#------------------------------------------------------------------------------------------------#
#---------------- Step6 : Start Rescoring the Pose For Screening  -----------------#
#------------------------------------------------------------------------------------------------#
echo '---------------- Step4 : Start Rescoring the Pose For Screening  -----------------'
# project_name='SurfDock_Screen_samples/repeat_zero'

# surface_out_dir=${SurfDockdir}/data/Screen_sample_dirs/${project_name}/test_samples_8A_surface
# data_dir=${SurfDockdir}/data/Screen_sample_dirs/test_samples
out_csv_file=${out_csv_dir}/score_inplace.csv

command=`accelerate launch \
${SurfDockdir}/inference_utils/construct_csv_input.py \
--data_dir ${data_dir} \
--surface_out_dir ${surface_out_dir} \
--output_csv_file ${out_csv_file} \
--Screen_ligand_library_file ${Screen_lib_path} \
--is_docking_result_dir \
--docking_result_dir ${docking_out_dir} \
`
state=$command

confidence_model_base_dir=${model_temp}/model_weights/screen

test_data_csv=${out_csv_file}

version=6
dist_arrays=(3)
for i in ${dist_arrays[@]}
do
mdn_dist_threshold_test=${i}
echo mdn_dist_threshold_test : ${mdn_dist_threshold_test}

command=`accelerate launch \
${SurfDockdir}/evaluate_score_in_place.py \
--data_csv ${test_data_csv} \
--confidence_model_dir ${confidence_model_base_dir} \
--confidence_ckpt best_model.pt \
--model_version version6 \
--mdn_dist_threshold_test ${mdn_dist_threshold_test} \
--esm_embeddings_path ${protein_embedding} \
--run_name ${project_name}_test_dist_${mdn_dist_threshold_test} \
--project ${project_name} \
--out_dir ${docking_out_dir} \
--batch_size 40 \
--wandb_dir ${temp}/wandb/test_workdir`
state=$command
done

cat << 'EOF'
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
  ____              __ ____             _      ____                        _ _               ____                   _  
 / ___| _   _ _ __ / _|  _ \  ___   ___| | __ / ___|  __ _ _ __ ___  _ __ | (_)_ __   __ _  |  _ \  ___  _ __   ___| | 
 \___ \| | | | '__| |_| | | |/ _ \ / __| |/ / \___ \ / _` | '_ ` _ \| '_ \| | | '_ \ / _` | | | | |/ _ \| '_ \ / _ \ | 
  ___) | |_| | |  |  _| |_| | (_) | (__|   <   ___) | (_| | | | | | | |_) | | | | | | (_| | | |_| | (_) | | | |  __/_| 
 |____/ \__,_|_|  |_| |____/ \___/ \___|_|\_\ |____/ \__,_|_| |_| |_| .__/|_|_|_| |_|\__, | |____/ \___/|_| |_|\___(_) 
                                                                    |_|              |___/                             
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
EOF