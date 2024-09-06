---
title: Template for the BABS bulk RNASeq pipeline
author: Gavin Kelly
---

## Introduction

This site provides the documentation on the BABS bulk RNASeq
pipeline. There are several somewhat distinct aspects to the
documentation, and they'll be covered on this site:

- [The nature of the 'spec' file](articles/spec.rmd) that determines the statistical
  analysis that will be carried out on the data.

- How the github repository turns itself into the starting point
  for a new project (e.g. obviously we don't want all the meta
  information, like this page, ending up in a user's project). I'm
  currently bringing over the functionality we use for stats projects
  which is much cleaner than the current approach, so this isn't yet
  documented.
  
- How to add extra functionality to the RNASeq template. People
  wanting to develop extra template functionality will want to start
  [here](articles/pipeline-infrastructure.html).
  
- What to do once you've got such a starting point for a new
  project. Users of the template will want to start
  [here](articles/BABS-RNASeq.html).

