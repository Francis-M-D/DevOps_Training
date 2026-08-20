#!/bin/bash

src="."
dest="data/backup_cripts_$(date +%F).tar.gz"
tar -czf $dest $src
