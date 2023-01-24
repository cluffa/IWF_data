# /bin/bash
apt-get update
apt-get install -y --no-install-recommends r-base python3 python3-pip r-cran-tidyverse
pip3 install -r requirements.txt
python3 test.py #updateAll.py
#Rscript clean.R