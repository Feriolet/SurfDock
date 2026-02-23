import subprocess
import os
import argparse
from pathlib import Path
import shutil
import yaml


def filepath_type(x):
    if x:
        return os.path.abspath(x)
    else:
        return x

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', metavar='FILENAME', required=False, type=filepath_type,
                        help='input file with molecules (SDF) to be docked.')
    parser.add_argument('-c', '--config', metavar='FILENAME', required=False, type=filepath_type,
                        help='YAML file with parameters used by docking program. See documentation for the format.')
    parser.add_argument('-o', '--output', metavar='FILENAME', required=False, type=filepath_type,
                        help='output folder for SurfDock')
    
    args = parser.parse_args()

    with open(args.config, 'r') as f:
        config_data = yaml.load(f, Loader=yaml.SafeLoader)

    if config_data['protein'][0] != '/':
        config_data['protein'] = Path(args.config).parent.joinpath(config_data['protein'])
    if config_data['ligand'][0] != '/':
        config_data['ligand'] = Path(args.config).parent.joinpath(config_data['ligand'])

    # prepare the protein directory. Protein-ligand complex must exist.
    current_dir = Path(__file__)
    surfdock_dir = current_dir.parent.parent.parent

    data_dir= Path(f'{surfdock_dir}/data/Screen_sample_dirs/easydock_samples')
    if not data_dir.is_dir():
        data_dir.mkdir(parents=True, exist_ok=True)
    
    protein_fname = Path(os.path.expanduser(os.path.expandvars(config_data['protein'])))
    if not protein_fname.is_file():
        raise TypeError('protein fname does not exist')

    if protein_fname.suffix != '.pdb':
        raise TypeError('protein need to be in PDB format')
    
    protein_surfdock_dir = Path(data_dir).joinpath(protein_fname.stem)
    protein_surfdock_dir.mkdir(parents=True, exist_ok=True)

    shutil.copyfile(str(protein_fname), str(protein_surfdock_dir / protein_fname.stem) + '_protein_processed.pdb')

    ligand_fname = Path(os.path.expanduser(os.path.expandvars(config_data['ligand'])))
    if not ligand_fname.is_file():
        raise TypeError('ligand fname does not exist')

    if ligand_fname.suffix != '.sdf':
        raise TypeError('ligand need to be in SDF format')

    shutil.copyfile(str(ligand_fname), str(protein_surfdock_dir / protein_fname.stem) + '_ligand.sdf')

    if config_data['processing_unit'] == 'gpu':
        script_fname = str(Path(__file__).parent.joinpath('screen_pipeline.sh'))
    elif config_data['processing_unit'] == 'cpu':
        script_fname = str(Path(__file__).parent.joinpath('screen_pipeline_cpu.sh'))
    else:
        raise ValueError('config value for processing unit must be either "cpu" or "gpu" (case sensitive)')
    
    cmd = [
    script_fname,
    args.input,
    args.output
    ]

    subprocess.run(' '.join(cmd), shell=True)