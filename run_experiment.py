#!/usr/bin/env python
import subprocess
import os.path
import sys
from random import shuffle

perl = subprocess.Popen(["which", "perl"],
                        stdout=subprocess.PIPE)\
                        .stdout\
                        .readline().strip()

models = ["ASP_PROTEASE.4.ASP.OD1",
"EF_HAND_1.1.ASP.OD1",
"EF_HAND_1.1.ASP.OD2",
"EF_HAND_1.9.GLN.NE2",
"IG_MHC.3.CYS.SG",
"PROTEIN_KINASE_ST.5.ASP.OD1",
"TRYPSIN_HIS.5.HIS.ND1"]

# to reduce the likelihood that two jobs will conflict with each other
# lets shuffle the order of models
shuffle(models)

for model in models:
    topns=range(2,21)
    shuffle(topns)
    for topn in topns:
        mtrys=range(2,topn+1)
        shuffle(mtrys)
        for mtry in mtrys:
            if mtry>topn: continue
            for ntree in [2000]:
                subprocess.call([perl, "./rf-xval.pl", model, str(ntree), str(mtry), str(topn)])
