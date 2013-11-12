<?

require "config.php";

function getDb()
{
    global $DBSTRING;
    return pg_connect($DBSTRING);
}

?>