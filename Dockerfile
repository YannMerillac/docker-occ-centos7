# Utilisation de l'image de base CentOS 7
FROM centos:7

# Mettre à jour les packages et installer les dépendances nécessaires
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
RUN yum update -y && \
    yum install -y centos-release-scl \
        gcc \
        gcc-c++ \
        wget \
        make \
        fontconfig \
        freetype \
        freetype-devel \
        fontconfig-devel \
        libstdc++ \
        mesa-libGL-devel \
        git \
        patchelf \
        libX11-devel

# Télécharger le script d'installation de Miniconda3
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py311_25.1.1-0-Linux-x86_64.sh -O /tmp/Miniconda3-latest-Linux-x86_64.sh

# Rendre le script exécutable et l'exécuter pour une installation silencieuse
RUN bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p /opt/miniconda3

# Supprimer le script d'installation
RUN rm /tmp/Miniconda3-latest-Linux-x86_64.sh

# Ajouter le répertoire bin de conda au PATH
ENV PATH="/opt/miniconda3/bin:${PATH}"

# Initialiser conda (pour éviter les avertissements)
RUN /opt/miniconda3/bin/conda init

# Créer un environnement conda avec Python 3.11
# RUN conda create -n py311 python=3.11 -y

# Activer l'environnement conda py311
#ENV CONDA_DEFAULT_ENV=py311
#ENV PATH="/opt/miniconda3/envs/py311/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/miniconda3/lib:${LD_LIBRARY_PATH}"

# Télécharger CMake 3.31.0
RUN wget https://github.com/Kitware/CMake/releases/download/v3.31.0/cmake-3.31.0-linux-x86_64.tar.gz -O /tmp/cmake-3.31.0-linux-x86_64.tar.gz

# Créer un répertoire pour CMake
RUN mkdir /opt/cmake

# Extraire CMake
RUN tar -xzf /tmp/cmake-3.31.0-linux-x86_64.tar.gz -C /opt/cmake --strip-components=1

# Ajouter CMake aux variables d'environnement PATH
ENV PATH="/opt/cmake/bin:${PATH}"

# Vérifier l'installation de CMake
RUN cmake --version

# Install swig
RUN wget http://prdownloads.sourceforge.net/swig/swig-4.2.1.tar.gz
RUN tar -zxvf swig-4.2.1.tar.gz -C /tmp
WORKDIR /tmp/swig-4.2.1
RUN ./configure
RUN make
RUN make install


# Install OCC lib
RUN wget https://github.com/Open-Cascade-SAS/OCCT/archive/refs/tags/V7_8_1.tar.gz
RUN tar -xvzf V7_8_1.tar.gz -C /tmp
RUN mkdir /tmp/OCCT-7_8_1/cmake-build
WORKDIR /tmp/OCCT-7_8_1/cmake-build
RUN cmake -DINSTALL_DIR=/opt/occt781 \
      -DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF \
      ..
RUN make -j4
RUN make install

RUN bash -c 'echo "/opt/occt781/lib" >> /etc/ld.so.conf.d/occt.conf'
RUN ldconfig

ENV LD_LIBRARY_PATH="/opt/occt781/lib:${LD_LIBRARY_PATH}"

# Install Rapidjson
WORKDIR /tmp
RUN git clone https://github.com/Tencent/rapidjson.git
WORKDIR /tmp/rapidjson
RUN git checkout v1.1.0
RUN cp -r include/rapidjson /usr/include

# Install pythonocc
WORKDIR /tmp
RUN git clone https://github.com/tpaviot/pythonocc-core.git
WORKDIR /tmp/pythonocc-core
RUN git checkout 7.8.1
RUN mkdir cmake-build
WORKDIR /tmp/pythonocc-core/cmake-build
RUN cmake \
    -DOCCT_INCLUDE_DIR=/opt/occt781/include/opencascade \
    -DOCCT_LIBRARY_DIR=/opt/occt781/lib \
    -DCMAKE_BUILD_TYPE=Release \
    -DPYTHONOCC_INSTALL_DIRECTORY=/opt/pythonocc/OCC \
    ..
RUN make -j4
RUN make install

RUN cp -r /opt/occt781/lib /opt/pythonocc/OCC

WORKDIR /opt/pythonocc
RUN echo -e "from setuptools import setup, find_packages\n\
try:\n\
    from wheel.bdist_wheel import bdist_wheel as _bdist_wheel\n\
    class bdist_wheel(_bdist_wheel):\n\
        def finalize_options(self):\n\
            _bdist_wheel.finalize_options(self)\n\
            self.root_is_pure = False\n\
except ImportError:\n\
    bdist_wheel = None\n\ 
setup(\n\
    name='pythonocc',\n\
    version='7.8.1',\n\
    packages=find_packages(),\n\
    include_package_data=True,\n\
    python_requires='~=3.11',\n\
    platforms='linux_x86_64',\n\
    cmdclass={'bdist_wheel': bdist_wheel},\n\
)" > "setup.py"

RUN echo -e "recursive-include OCC/ *.so*\nrecursive-include OCC/ *.py" > "MANIFEST.in"

RUN echo -e "import subprocess\n\
from pathlib import Path\n\
import os\n\
from glob import glob\n\
 \n\
def get_shared_library_dependencies(so_file):\n\
    list_lib = []\n\
    # Run the ldd command and capture the output\n\
    result = subprocess.run(['ldd', so_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)\n\
   \n\
    if result.returncode != 0:\n\
        print(f'Error occurred while trying to run ldd on {so_file}:')\n\
        print(result.stderr)\n\
        return\n\
   \n\
    # Print the dependencies\n\
    dependencies = result.stdout.strip().splitlines()\n\
    #print(f'Shared library dependencies for {so_file}:')\n\
    for line in dependencies:\n\
        list_lib.append(line.split()[0])\n\
 \n\
    return list_lib\n\
   \n\
   \n\
 \n\
if __name__ == '__main__':\n\
    # get occ libs\n\
    occ_lib_list = [Path(lib).name for lib in glob('OCC/lib/*.so*')]\n\
    print(occ_lib_list)\n\
    # loop over so file\n\
    for so_file in glob('OCC/*/*.so', recursive=True):\n\
        print(so_file)\n\
        try:\n\
            for dep in get_shared_library_dependencies(so_file):\n\
                dep_name = Path(dep).name\n\
                if dep_name in occ_lib_list:\n\
                    if Path(so_file).parts[1] == 'lib':\n\
                        cmd = f'''patchelf --set-rpath '\$ORIGIN' {so_file}'''\n\
                    else:\n\
                        cmd = f'''patchelf --set-rpath '\$ORIGIN/../lib' {so_file}'''\n\
                    os.system(cmd)\n\
        except:\n\
            print(f'Failed on {so_file}')\n" > "fix_so_dependancies.py"

RUN pip install patchelf
RUN python fix_so_dependancies.py
RUN python setup.py bdist_wheel

# Définir le répertoire de travail
WORKDIR /app

# Commande à exécuter au démarrage du conteneur
CMD ["/bin/bash"]