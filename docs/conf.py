# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import sphinx_rtd_theme
import os
import sys
sys.path.insert(0, os.path.abspath('.'))
sys.path.insert(0, os.path.abspath('sphinx_rtd_theme'))


# -- Project information -----------------------------------------------------

project = 'VVM'
copyright = '2025, The VPLanet Team'
author = 'Rory Barnes'

release = '1.0'


# -- General configuration ---------------------------------------------------

templates_path = ['_templates']

exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']


# -- Options for HTML output -------------------------------------------------

html_theme = 'sphinx_rtd_theme'

html_theme_options = {
    'logo_only': True,
}

html_logo = 'VPLanetLogo.png'

html_static_path = ['_static']
