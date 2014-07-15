alter type tag_status add value if not exists 'IGNORED';

begin;

select speedycrew.require_change('change_20140713.sql');

select speedycrew.provide_change('change_20140715.sql');

-- the following word list was nicked from http://www.textfixer.com/resources/common-english-words.txt which was found on http://en.wikipedia.org/wiki/Stop_words

with words as (select unnest(string_to_array('a,able,about,across,after,all,almost,also,am,among,an,and,any,are,as,at,be,because,been,but,by,can,cannot,could,dear,did,do,does,either,else,ever,every,for,from,get,got,had,has,have,he,her,hers,him,his,how,however,i,if,in,into,is,it,its,just,least,let,like,likely,may,me,might,most,must,my,neither,no,nor,not,of,off,often,on,only,or,other,our,own,rather,said,say,says,she,should,since,so,some,than,that,the,their,them,then,there,these,they,this,tis,to,too,twas,us,wants,was,we,were,what,when,where,which,while,who,whom,why,will,with,would,yet,you,your', ',')) as word) insert into tag select nextval('tag_id_seq'::regclass), word, null, 'IGNORED', now() from words where not exists (select * from tag where name = words.word);

commit;

