FROM dynverse/dynwrapr:v0.1.0

ARG GITHUB_PAT

RUN git clone https://github.com/hmatsu1226/SCOUP.git && cd SCOUP && make all

COPY definition.yml run.R example.h5 /code/

ENTRYPOINT ["/code/run.R"]
