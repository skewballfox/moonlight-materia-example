#!/bin/sh
# SetupScript and PostScript of the nvidia-driver component. Materia runs it as
# root after it has staged the component and before it asks the account's
# materia to update, while it holds its lock. Forma creates the account and
# its materia, and everything else the component declares.
exec forma apply nvidia-driver --materia-lock held
