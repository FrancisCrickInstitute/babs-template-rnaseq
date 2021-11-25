#!/bin/bash
mkdir {% for genome in cookiecutter.genomes %}{{genome}} {% endfor %}
