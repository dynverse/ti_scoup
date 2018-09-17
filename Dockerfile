FROM dynverse/dynwrap:r

LABEL version 0.1.2

RUN git clone https://github.com/hmatsu1226/SCOUP.git && cd SCOUP && make all

ADD . /code

ENTRYPOINT Rscript /code/run.R
