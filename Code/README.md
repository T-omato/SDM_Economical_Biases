## Establishing_jupyterNotebook

Contains a step by step guide for setting up the virtual environment to work on the huggingface dataset. 

## DivShift_NAWC.ipynb

Contains code for accesing elenagsierra/DivShift-NAWC dataset from huggingface. The data accessed is divshift_nawc.csv.
The code parses the .csv file by chunksizes of 10000 for all row entries containing "california".
Finally, the filtered dataset is saved as a subset of specified columns. In this instance only ""observer_id", "latitude", "longitude", "positional_accuracy", "taxon_id","observed_on", "human_footprint""
were saved 

## DivShift_California.ipynb

Visualizes the observation and human footprint index data on a california map. Adds a reference scalebar to show 750km. 
