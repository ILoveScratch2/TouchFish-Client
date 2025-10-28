from distutils.core import setup
from setuptools import find_packages

with open("README.rst", "r") as f:
  long_description = f.read()

setup(name='touchfish_client',
      version='0.1.1',
      description='TouchFish 客户端模块',
      long_description=long_description,
      author='ILoveScratch2',
      author_email='ilovescratch@foxmail.com',
      url='https://github.com/ILoveScratch2/TouchFish-Client.git',
      install_requires=[],
      license='MPL License',
      packages=find_packages(),
      platforms=["all"],
      classifiers=[
          'Intended Audience :: Developers',
          'Operating System :: OS Independent',
          'Natural Language :: Chinese (Simplified)',
          'Programming Language :: Python',
          'Programming Language :: Python :: 3',
          'Programming Language :: Python :: 3.6',
          'Programming Language :: Python :: 3.7',
          'Programming Language :: Python :: 3.8',
          'Topic :: Software Development :: Libraries'
      ],
      )
