FROM debian:bookworm AS spython-base
ADD certs/bundle-ca.crt /etc/ssl/certs
ADD certs/bundle-ca.crt /usr/local/share/ca-certificates/
ADD odbc/clouderaimpalaodbc_2.6.14.1016-2_amd64.deb /clouderaimpalaodbc_2.6.14.1016-2_amd64.deb
ADD odbc/odbcinst.ini /odbcinst.ini
ADD odbc/cloudera.impalaodbc.ini /cloudera.impalaodbc.ini
ADD odbc/odbc.ini /odbc.ini
ENV ODBCINI=/etc/odbc.ini
ENV ODBCSYSINI=/etc
ENV CLOUDERAIMPALAINI=/opt/cloudera/impalaodbc/lib/64/cloudera.impalaodbc.ini
ENV LD_LIBRARY_PATH=/opt/cloudera/impalaodbc/lib/64:/usr/local/unixODBC:$LD_LIBRARY_PATH
RUN DEBIAN_FRONTEND=noninteractive
RUN apt-get update --fix-missing -y
RUN apt-get install -y curl gnupg lsb-release \
r-base r-base-dev \
r-cran-tidyverse \
ca-certificates \
build-essential \
bzip2 wget \
dos2unix \
debhelper \
libcurl4-openssl-dev \
libssl-dev cmake \
libmariadb-dev \
unixodbc-dev \
unixodbc
RUN wget --no-check-certificate https://www.unixodbc.org/unixODBC-2.3.12.tar.gz
RUN tar -xvzf unixODBC-2.3.12.tar.gz
RUN cd unixODBC-2.3.12
RUN ./configure --prefix=/usr/local/unixODBC
RUN make
RUN make install
RUN cd ../
RUN dpkg -i clouderaimpalaodbc_2.6.14.1016-2_amd64.deb
RUN cp /odbc.ini /etc/odbc.ini
RUN cp /odbcinst.ini /etc/odbcinst.ini
RUN cp /cloudera.impalaodbc.ini /opt/cloudera/impalaodbc/lib/64/cloudera.impalaodbc.ini
RUN wget https://packages.apache.org/artifactory/arrow/$(lsb_release --id --short | tr 'A-Z' 'a-z')/apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb
RUN apt-get install -y -V ./apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb
RUN apt-get update
RUN apt-get install -y -V libarrow-dev # For C++
RUN apt-get install -y -V libarrow-glib-dev # For GLib (C)
RUN apt-get install -y -V libarrow-dataset-dev # For Apache Arrow Dataset C++
RUN apt-get install -y -V libarrow-dataset-glib-dev # For Apache Arrow Dataset GLib (C)
RUN apt-get install -y -V libarrow-acero-dev # For Apache Arrow Acero
RUN apt-get install -y -V libarrow-flight-dev # For Apache Arrow Flight C++
RUN apt-get install -y -V libarrow-flight-glib-dev # For Apache Arrow Flight GLib (C)
RUN apt-get install -y -V libarrow-flight-sql-dev # For Apache Arrow Flight SQL C++
RUN apt-get install -y -V libarrow-flight-sql-glib-dev # For Apache Arrow Flight SQL GLib (C)
RUN apt-get install -y -V libgandiva-dev # For Gandiva C++
RUN apt-get install -y -V libgandiva-glib-dev # For Gandiva GLib (C)
RUN apt-get install -y -V libparquet-dev # For Apache Parquet C++
RUN apt-get install -y -V libparquet-glib-dev
RUN update-ca-certificates
RUN R -e 'install.packages(c("optparse", "DBI", "odbc", "ape", "kmer", "BiocManager", "caret", "doParallel", "parallel", "foreach", "kknn"), dependencies = TRUE)'
RUN R -e 'install.packages("nanoparquet")'
RUN R -e 'BiocManager::install("Biostrings", force =  TRUE, update = FALSE, ask = FALSE)'
RUN rm -rf /var/lib/apt/lists/*
