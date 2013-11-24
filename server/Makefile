DEV_PATH=/home/speedycrew/dev.speedycrew.com

TIMESTAMP=$(shell date +%Y%m%d-%H%M%S)

push_to_dev:
	cp -r django_project $(DEV_PATH)/django_project.$(TIMESTAMP)
	chgrp -R speedycrew $(DEV_PATH)/django_project.$(TIMESTAMP)
	rm -f $(DEV_PATH)/django_project
	ln -s django_project.$(TIMESTAMP) $(DEV_PATH)/django_project
	chgrp -h speedycrew $(DEV_PATH)/django_project
