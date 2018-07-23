import os
import json
import pandas as pd

from EpiMap.datasets import miRNA2Disease

miR2D_dataset = miRNA2Disease()


def load_results(filename):
    df = pd.read_csv(filename, header=0, sep='\t')

    return df


def load_json(filename):
    with open(filename, 'r') as fin:
        json_data = json.load(fin)

    return json_data['nodes'], json_data['links']


class EBEN_json():
    main_nodes = []
    epis_nodes = []
    target_nodes = []

    nodes_json = []
    links_json = []
    legend_json = []

    def __init__(self, job_dir):
        self.job_dir = job_dir
        main_results_filename = os.path.join(self.job_dir, 'EBEN.main_result.txt')
        epis_results_filename = os.path.join(self.job_dir, 'EBEN.epis_result.txt')

        self.main_results = load_results(main_results_filename)
        self.epis_results = load_results(epis_results_filename)
        self.miRNA_target = miR2D_dataset.miRNA_target

    def generate_nodes_json(self):
        self.main_nodes = self.main_results['feature'].drop_duplicates()
        self.epis_nodes = pd.concat([self.epis_results['feature1'],
                                     self.epis_results['feature2']]).drop_duplicates()
        all_miRNA_nodes = pd.concat([self.main_nodes, self.epis_nodes]).drop_duplicates()

        self.nodes_json = []
        for node in all_miRNA_nodes:
            if node in self.main_nodes.values:
                self.nodes_json.append({'id': node,
                                        'shape': 'triangle',
                                        'size': 100,
                                        'fill': 'red',
                                        'group': 'main_miRNA',
                                        'label': node,
                                        'level': 1})
            elif node in self.epis_nodes.values:
                self.nodes_json.append({'id': node,
                                        'shape': 'triangle',
                                        'size': 100,
                                        'fill': 'blue',
                                        'group': 'epis_miRNA',
                                        'label': node,
                                        'level': 1})

        # filter related target nodes with ignore case
        self.related_target = self.miRNA_target[
            self.miRNA_target['miRNA'].str.lower().isin(all_miRNA_nodes.str.lower())].drop_duplicates()
        self.target_nodes = self.related_target['Validated target'].drop_duplicates()
        for node in self.target_nodes.values:
            self.nodes_json.append({'id': node,
                                    'shape': 'circle',
                                    'size': 50,
                                    'fill': 'purple',
                                    'group': 'target',
                                    'label': node,
                                    'level': 2})

        return self.nodes_json

    def generate_links_json(self):
        self.links_json = []
        # add epis link
        epis_links = self.epis_results[['feature1', 'feature2']].drop_duplicates()
        for index, link in epis_links.iterrows():
            self.links_json.append({'source': link['feature1'],
                                    'target': link['feature2'],
                                    'color': 'black',
                                    'strength': 0.3})

        # add target link
        target_links = self.related_target[['miRNA', 'Validated target']].drop_duplicates()

        for index, link in target_links.iterrows():
            self.links_json.append({'source': link['miRNA'].lower(),
                                    'target': link['Validated target'],
                                    'color': 'green',
                                    'strength': 0.5})

        return self.links_json

    def generate_legend_json(self):
        self.legend_json = [
            {
                'label': 'main_miRNA',
                'shape': 'triangle',
                'color': 'red'
            },
            {
                'label': 'epis_miRNA',
                'shape': 'triangle',
                'color': 'green'
            },
            {
                'label': 'target',
                'shape': 'circle',
                'color': 'blue'
            }
        ]
        return self.legend_json

    def write_json(self):
        filename = os.path.join(self.job_dir, 'nodes_links.json')
        json_data = {'nodes': self.nodes_json,
                     'links': self.links_json}
        with open(filename, 'w') as fout:
            json.dump(json_data, fout, indent=4)