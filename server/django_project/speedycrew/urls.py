from django.conf.urls import patterns, include, url

# Uncomment the next two lines to enable the admin:
# from django.contrib import admin
# admin.autodiscover()

urlpatterns = patterns('',

    url(r'^api/1/schedule/([a-zA-Z0-9_-]+)$', 'scapi1.views.schedule', name='schedule'),
    url(r'^api/1/find/([0-9]{4}-[0-9]{2}-[0-9]{2})/([a-z0-9-]+)$', 'scapi1.views.find', name='find'),

    # Examples:
    # url(r'^$', 'speedycrew.views.home', name='home'),
    # url(r'^speedycrew/', include('speedycrew.foo.urls')),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    # url(r'^admin/', include(admin.site.urls)),
)
