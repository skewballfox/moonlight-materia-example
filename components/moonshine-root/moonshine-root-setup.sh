#!/bin/sh
# SetupScript and PostScript of the moonshine-root component. Root materia
# runs it as root, with every other component's scripts, before it asks the
# account's materia to update, while it holds its lock. Forma creates the
# account and its materia, and everything moonshine-root declares for it.
exec forma apply moonshine-root --materia-lock held
