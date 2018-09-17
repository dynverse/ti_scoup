FROM dynverse/dynwrap:r

RUN git clone https://github.com/hmatsu1226/SCOUP.git && cd SCOUP && make all

LABEL version 0.1.2

ADD . /code

ENTRYPOINT Rscript /code/run.R
