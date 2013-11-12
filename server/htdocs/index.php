<html>
<h1>Exploratory prototyping for scheduler app</h1>

<p>Assumptions: an app runs on a handheld device that has internet
access and can make HTTP requests and handle JSON responses.  Or
something.</p>

<h2>Searching for people</h2>

<p>Maybe these searches could be based on your 'circle'.  In this prototype we just search everyone who has an account that is <code>ACTIVE</code>.  You might also want to support more than one skill at the same time (not implemented here).</p>

<ul>
<li><a href="find.php?day=2013-11-10&skill=sous-chef">find</a> -- Find a person with skill <code>sous-chef</code> who is available on 2013-11-10</li>
<li><a href="find.php?day=2013-11-11&skill=bottle-washer">find</a> -- Looking for <code>bottle-washer</code> on 2013-11-11</li>
</ul>

<h2>Querying a peer's schedule</h2>

<p>Perhaps this would only be allowed if you are authenticated and the peer is in your circle.  But for this prototype it's open access.</p>

<ul>
<li><a href="schedule.php?username=maguire_the_knife">schedule</a> -- Fetch schedule for user <code>maguire_the_knife</code></li>
<li><a href="schedule.php?username=spudpeeler">schedule</a> -- Fetch schedule for user <code>spudpeeler</code></li>
<li><a href="schedule.php?username=coulis">schedule</a> -- Fetch schedule for user <code>coulis</code></li>
</ul>

<h2>Various updates</h2>

<p>Authentication would probably be based on logging in and getting a session token, to be used with all future requests.  But for toying around, username and password are used here:</p>

<ul>
<li>
<form target="set_message.php">
Set message: 
username=
<input type="username" value="maguire_the_knife"/>,
password=
<input type="password" value="foo"/>,
message=
<input type="message"/>
<input type="submit" value="Send"/>
</form>
</li>
</ul>

</html>
