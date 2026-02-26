import subprocess
import os
import argparse
from pathlib import Path
import shutil
import yaml
import pandas as pd
import rdkit
from rdkit import Chem
import tempfile


def filepath_type(x):
    if x:
        return os.path.abspath(x)
    else:
        return x

def prepare_protein_ligand_for_surfdock(tempdir: str, protein_fname: str, ligand_fname: str) -> str:

    data_dir= Path(f'{tempdir}/data/Screen_sample_dirs/easydock_samples')
    if not data_dir.is_dir():
        data_dir.mkdir(parents=True, exist_ok=True)

    if not protein_fname.is_file():
        raise TypeError('protein fname does not exist')

    if protein_fname.suffix != '.pdb':
        raise TypeError('protein need to be in PDB format')
    
    protein_surfdock_dir = Path(data_dir).joinpath(protein_fname.stem)
    protein_surfdock_dir.mkdir(parents=True, exist_ok=True)

    shutil.copyfile(str(protein_fname), str(protein_surfdock_dir / protein_fname.stem) + '_protein_processed.pdb')

    if not ligand_fname.is_file():
        raise TypeError('ligand fname does not exist')

    if ligand_fname.suffix != '.sdf':
        raise TypeError('ligand need to be in SDF format')

    shutil.copyfile(str(ligand_fname), str(protein_surfdock_dir / protein_fname.stem) + '_ligand.sdf')


def parse_surfdock_mol_df(mol_series: pd.Series) -> Chem.Mol:

    sdf_path = Path(mol_series['pose_file_path'].split('_', 1)[-1])
    if not sdf_path.is_file():
        return None

    mol = Chem.SDMolSupplier(str(sdf_path))[0]
    if not isinstance(mol, Chem.Mol):
        return None
    
    mol.SetProp('pose_prediction_confidence', str(mol_series['pose_prediction_confidence(for pose rank)']))
    mol.SetProp('screen_confidence', str(mol_series['screen_confidence(for molecule rank)']))
    mol.SetProp('pose_rank', str(mol_series['pose_rank']))

    return mol


def analyse_output(tempdir: str, output_fname: str) -> None:

    output_path = Path(tempdir) / 'docking_result'
    output_csv_fname = output_path.joinpath(OUTPUT_CSV_FNAME)

    if not output_csv_fname.is_file():
        raise FileNotFoundError('SurfDock output is not detected.')
    
    surfdock_output_df = pd.read_csv(output_csv_fname, engine='pyarrow')
    surfdock_output_df_grouped = surfdock_output_df.groupby('molecule_name')
    
    mol_l = []
    for mol_name_key, df_by_mol_name in surfdock_output_df_grouped:
        mol_l += list(df_by_mol_name.sort_values(by=['pose_rank']).apply(parse_surfdock_mol_df, axis=1))
    
    with Chem.SDWriter(str(output_path.joinpath(output_fname))) as w:
        for m in mol_l:
            w.write(m)


if __name__ == '__main__':
    DEFAULT_NPOSE_DOCKING = 40
    OUTPUT_CSV_FNAME = 'score_inplace_confidence.csv'

    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', metavar='FILENAME', required=True, type=filepath_type,
                        help='input file with molecules (SDF).')
    parser.add_argument('-c', '--config', metavar='FILENAME', required=True, type=filepath_type,
                        help='YAML file with parameters used by docking program. See documentation for the format.')
    parser.add_argument('-o', '--output', metavar='FILENAME', required=True, type=filepath_type,
                        help='output SDF file for SurfDock')
    
    args = parser.parse_args()

    if Path(args.input).suffix != '.sdf':
        raise ValueError('input molecules should be in SDF file')

    if Path(args.output).suffix != '.sdf':
        raise ValueError('output molecules should be in SDF file')

    with open(args.config, 'r') as f:
        config_data = yaml.load(f, Loader=yaml.SafeLoader)

    if config_data['protein'][0] != '/':
        config_data['protein'] = Path(args.config).parent.joinpath(config_data['protein'])
    if config_data['ligand'][0] != '/':
        config_data['ligand'] = Path(args.config).parent.joinpath(config_data['ligand'])


    if config_data['processing_unit'] == 'gpu':
        script_fname = str(Path(__file__).parent.joinpath('screen_pipeline.sh'))
    elif config_data['processing_unit'] == 'cpu':
        script_fname = str(Path(__file__).parent.joinpath('screen_pipeline_cpu.sh'))
    else:
        raise ValueError('config value for processing unit must be either "cpu" or "gpu" (case sensitive)')
    
    n_gen_pose = DEFAULT_NPOSE_DOCKING
    if 'n_gen_poses' in config_data:
        if not isinstance(config_data['n_gen_poses'], int):
            print('npose config is not an integer, ignoring the input and setting up default to 40')
        else:
            n_gen_pose = config_data['n_gen_poses']

    n_save_pose = DEFAULT_NPOSE_DOCKING
    if 'n_save_poses' in config_data:
        if not isinstance(config_data['n_save_poses'], int):
            print('npose config is not an integer, ignoring the input and setting up default to 40')
        else:
            n_save_pose = config_data['n_save_poses']

    if n_save_pose > n_gen_pose:
        print('n_save_poses is larger than n_gen_poses. Reconfigure n_save_poses = n_gen_poses')
        n_save_pose = n_gen_pose

    n_gen_pose = str(n_gen_pose) #subprocess requires to stringify everything
    n_save_pose = str(n_save_pose) #subprocess requires to stringify everything

    protein_fname = Path(os.path.expanduser(os.path.expandvars(config_data['protein'])))
    ligand_fname = Path(os.path.expanduser(os.path.expandvars(config_data['ligand'])))

    tmpdir = None
    if 'tempdir' in config_data:
        if config_data['tempdir'][0] != '/':
            tmpdir = str(Path(args.config).parent.joinpath(config_data['tempdir']))
        else:
            tmpdir = config_data['tempdir']
        
        if not Path(tmpdir).is_dir():
            Path(tmpdir).mkdir()
    
    with tempfile.TemporaryDirectory(dir=tmpdir) as easydock_dir:
        prepare_protein_ligand_for_surfdock(tempdir=easydock_dir,
                                            protein_fname=protein_fname,
                                            ligand_fname=ligand_fname)
        cmd = [
        script_fname,
        args.input,
        n_gen_pose,
        n_save_pose,
        easydock_dir
        ]

        subprocess.run(' '.join(cmd), shell=True)
        analyse_output(easydock_dir, args.output)