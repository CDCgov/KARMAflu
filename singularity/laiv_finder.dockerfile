FROM r-base:4.5.0 AS spython-base
ADD certs/bundle-ca.crt /etc/ssl/certs
ADD certs/bundle-ca.crt /usr/local/share/ca-certificates/
RUN DEBIAN_FRONTEND=noninteractive
RUN apt-get update --fix-missing -y
RUN apt-get upgrade -y
RUN apt-get install -y r-cran-tidyverse git ca-certificates
RUN update-ca-certificates
RUN R -e 'install.packages("optparse", dependencies = TRUE)'
RUN R -e 'install.packages("Rcpp", dependencies = TRUE)'
RUN git clone https://github.com/sdwfrost/libtn93.git
RUN mv libtn93/Rcpp/tn93.cpp /usr/local/bin/tn93.cpp && chmod +x /usr/local/bin/tn93.cpp
CMD exec /bin/bash "$@"
