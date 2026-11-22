#!/bin/sh
# CleanupScript of the moonshine-root component. Forma removes what it
# created for the component; the account's home is kept.
exec forma revert moonshine-root --materia-lock held
