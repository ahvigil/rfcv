#!/usr/bin/env ipython
import subprocess
import os.path
import sys
import urllib
from random import shuffle

os.chdir(os.path.dirname(__file__))

perl = subprocess.Popen(["which", "perl"],
                        stdout=subprocess.PIPE)\
                        .stdout\
                        .readline().strip()

ntree = 500
if len(sys.argv) > 1:
    ntree = int(sys.argv[-1])

if not os.path.exists("./performance"):
    os.makedirs("./performance")
if not os.path.exists("./cache"):
    os.makedirs("./cache")
if not os.path.exists("./data"):
    os.makedirs("./data")

models = ["ASP_PROTEASE.4.ASP.OD1",
"EF_HAND_1.1.ASP.OD1",
"EF_HAND_1.1.ASP.OD2",
"EF_HAND_1.9.GLN.NE2",
"IG_MHC.3.CYS.SG",
"PROTEIN_KINASE_ST.5.ASP.OD1",
"TRYPSIN_HIS.5.HIS.ND1"]

def fetch_data():
    purl = "http://feature.stanford.edu/webfeature/models/{0}/{0}.pos.ff.gz"
    nurl = "http://feature.stanford.edu/webfeature/models/{0}/{0}.neg.ff.gz"
    pfile = os.path.join(os.getcwd(), "data", "{0}", "{0}.pos.ff.gz")
    nfile = os.path.join(os.getcwd(), "data", "{0}", "{0}.neg.ff.gz")

    for model in models:
        if os.path.exists(pfile.format(model)):
            print "{} already exists".format(pfile.format(model))
        else:
            if not os.path.exists(os.path.dirname(pfile)):
                os.makedirs(os.path.dirname(pfile.format(model)))
                urllib.urlretrieve(purl.format(model), pfile.format(model))
            print "created file " + pfile.format(model)

        if os.path.exists(nfile.format(model)):
            print "{} already exists".format(nfile.format(model))
        else:
            urllib.urlretrieve(nurl.format(model), nfile.format(model))
            print "created file " + nfile.format(model)

fetch_data()

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
            subprocess.call([perl, "./rf-xval.pl", model, str(ntree), str(mtry), str(topn)])
