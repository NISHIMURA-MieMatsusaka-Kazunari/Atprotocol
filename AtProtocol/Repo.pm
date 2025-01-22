package AtProtocol::Repo;

use strict;
use warnings;
use utf8;
use Encode qw(encode decode);
use parent qw(AtProtocol);
use LWP::UserAgent;
use HTTP::Request;
use JSON;

use constant {
	##UserAgent
	USERAGENT	=> 'AtProtocol::Repo',
	##at protocol
	PDS_URI_A	=> 'https://bsky.social',
	POST		=> 'app.bsky.feed.post',
	EMBED		=> 'app.bsky.embed.external',
	LANG		=> 'jp-JP',
};

# constructor
sub new {
	my $class		= shift;
	my $identifier 	= shift;
	my $password	= shift;
	my $directory	= shift;
	my $option		= shift;
	my $postType		= $option ? ($option->{postType}	? $option->{postType}	: POST)		: POST;
	my $embedType		= $option ? ($option->{embedType}	? $option->{embedType}	: EMBED)	: EMBED;
	my $langs			= $option ? ($option->{langs}		? $option->{langs}		: [LANG])	: [LANG];
	$option->{userAgent}	= $option ? ($option->{userAgent}	? $option->{userAgent}	: USERAGENT)	: USERAGENT;
	$option->{pdsUri}		= $option ? ($option->{pdsUri}		? $option->{pdsUri}		: PDS_URI_A)	: PDS_URI_A;
	my $self;
	eval{
		if($identifier && $password && $directory){
			$self = AtProtocol->new($identifier, $password, $directory, $option) or die($!);
			$self->{postType}	= $postType;
			$self->{embedType}	= $embedType;
			$self->{langs}		= $langs;
		}else{
			die("Err not set Identifier and Password.");
		}
	};
	if($@){
		chomp($@);
		$! = $@;
		return undef;
	}else{
		return bless $self, $class;
	}
}
# destructor
sub DESTROY {
	my $self = shift;
	$self->SUPER::DESTROY();
}

###  API atproto.repo
# com.atproto.repo.createRecord
sub createRecord {
	my $self	= shift;
	my $record	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $uri			= $option ? ($option->{uri}			? $option->{uri}		: undef					): undef;
	my $did			= $option ? ($option->{did}			? $option->{did}		: $self->{did}			): $self->{did};
	my $collection	= $option ? ($option->{postType}	? $option->{postType}	: $self->{postType}		): $self->{postType};
	my $rkey		= $option ? ($option->{rkey}		? $option->{rkey}		: undef					): undef;
	my $validate	= $option ? ($option->{validate}	? $option->{validate}	: undef					): undef;
	my $swapCommit	= $option ? ($option->{swapCommit}	? $option->{swapCommit}	: undef					): undef;
	if($uri && ($uri =~ /^at:\/\/([^\/]+)\/([^\/]+)\/([^\/]+)$/i)){
		$did		= $1;
		$collection	= $2;
		$rkey 		= $3;
	}
	my $ret			= undef;
	eval{
		my %param = (
			repo => $did, 
			collection => $collection,
			record => $record
		);
		$rkey		&& ($param{rkey}		= $rkey);
		$validate	&& ($param{validate}	= $validate ? 'true' : 'false');
		$swapCommit	&& ($param{swapCommit}	= $swapCommit);
		my $jsont = encode_json(\%param);
		#print "param: $jsont\n\n";
		my $req = HTTP::Request->new ('POST', 
			$self->{serviceEndpoint}.'/xrpc/com.atproto.repo.createRecord', 
			['Authorization' => 'Bearer '.$self->{accessJwt}, 'Content-Type' => 'application/json', 'Accept' => 'application/json'], 
			$jsont)
			or die("Failed to initialize HTTP::Request(com.atproto.repo.createRecord): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error}  createRecord: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.deleteRecord
sub deleteRecord {
	my $self	= shift;
	my $uri		= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $swapRecord	= $option ? ($option->{swapRecord}	? $option->{swapRecord}	: undef					): undef;
	my $swapCommit	= $option ? ($option->{swapCommit}	? $option->{swapCommit}	: undef					): undef;
	my $ret			= undef;
	eval{
		my $did			= undef;
		my $collection	= undef;
		my $rkey 		= undef;
		if($uri =~ /^at:\/\/([^\/]+)\/([^\/]+)\/([^\/]+)$/i){
			$did		= $1;
			$collection	= $2;
			$rkey 		= $3;
		}else{
			die("cannot get rkey: $uri");
		}
		my %param = (
		repo		=> $did,
		collection 	=> $collection, 
		rkey		=> $rkey,
		);
		$swapRecord	&& ($param{swapRecord}	= $swapRecord);
		$swapCommit	&& ($param{swapCommit}	= $swapCommit);
		my $jsont = encode_json(\%param);
		#print "Json: $jsont\n";
		my $req = HTTP::Request->new ('POST', 
		$self->{serviceEndpoint}.'/xrpc/com.atproto.repo.deleteRecord', 
		['Authorization' => 'Bearer '.$accessJwt, 'Content-Type' => 'application/json', 'Accept' => 'application/json'],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.deleteRecord): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$self->{content} = $json;
		$json->{commit}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.putRecord
sub putRecord {
	my $self	= shift;
	my $uri		= shift;
	my $record	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $validate	= $option ? ($option->{validate}	? $option->{validate}	: undef					): undef;
	my $swapRecord	= $option ? ($option->{swapRecord}	? $option->{swapRecord}	: undef					): undef;
	my $swapCommit	= $option ? ($option->{swapCommit}	? $option->{swapCommit}	: undef					): undef;
	my $ret			= undef;
	eval{
		my $did			= undef;
		my $collection	= undef;
		my $rkey 		= undef;
		if($uri =~ /^at:\/\/([^\/]+)\/([^\/]+)\/([^\/]+)$/i){
			$did		= $1;
			$collection	= $2;
			$rkey 		= $3;
		}else{
			die("cannot get rkey: $uri");
		}

		my %param = (
		repo		=> $did,
		collection 	=> $collection, 
		rkey		=> $rkey,
		record		=> $record,
		);
		$validate	&& ($param{validate}	= $validate ? 'true' : 'false');
		$swapRecord	&& ($param{swapRecord}	= $swapRecord);
		$swapCommit	&& ($param{swapCommit}	= $swapCommit);
		my $jsont = encode_json(\%param);
		#print "Json: $jsont\n";
		my $req = HTTP::Request->new ('POST', 
		$self->{serviceEndpoint}.'/xrpc/com.atproto.repo.putRecord', 
		['Authorization' => 'Bearer '.$accessJwt, 'Content-Type' => 'application/json', 'Accept' => 'application/json'],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.putRecord): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$self->{content} = $json;
		$json->{commit}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.getRecord
sub getRecord {
	my $self	= shift;
	my $uri		= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $cid			= $option ? ($option->{cid}			? $option->{cid}		: undef					): undef;
	my $ret			= undef;
	eval{
		my $did			= undef;
		my $collection	= undef;
		my $rkey 		= undef;
		if($uri =~ /^at:\/\/([^\/]+)\/([^\/]+)\/([^\/]+)$/i){
			$did		= $1;
			$collection	= $2;
			$rkey 		= $3;
		}else{
			die("cannot get rkey: $uri");
		}
		my %param = (
		repo		=> $did,
		collection 	=> $collection, 
		rkey		=> $rkey,
		);
		$cid	&& ($param{cid}	= $cid);
		my $query = $self->makeQuery(\%param);
		#print "Query: $query\n";
		my $req = HTTP::Request->new ('GET', 
		$self->{serviceEndpoint}.'/xrpc/com.atproto.repo.getRecord?'.$query, 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json'],
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.getRecord?$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$self->{content} = $json;
		$json->{uri}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.listRecords
sub listRecords {
	my $self	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $did			= $option ? ($option->{did}			? $option->{did}		: $self->{did}			): $self->{did};
	my $collection	= $option ? ($option->{postType}	? $option->{postType}	: $self->{postType}		): $self->{postType};
	my $limit		= $option ? ($option->{limit}		? $option->{limit}		: undef					): undef;
	my $cursor		= $option ? ($option->{cursor}		? $option->{cursor}		: undef					): undef;
	my $rev			= $option ? ($option->{rev}			? $option->{rev}		: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = (
			repo => $did,
			collection => $collection,
		);
		$limit			&& ($param{limit}		= $limit);
		$cursor			&& ($param{cursor}		= $cursor);
		defined($rev)	&& ($param{'reverse'}	= $rev ? 'true' : 'false');
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new ('GET', 
		$self->{serviceEndpoint}.'/xrpc/com.atproto.repo.listRecords?'.$query, 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json'],
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.listRecords?$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$self->{content} = $json;
		$json->{records}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.uploadBlob
sub uploadBlob {
	my $self	= shift;
	my $pict	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}		: $self->{accessJwt}	):  $self->{accessJwt};
	my $ret			= undef;
	eval{
		my $temp		= checkMagicByte($pict);
		#print "content-type: $temp\n";
		my $contentType	= $option ? ($option->{contentType}	? $option->{contentType}	: $temp				):  $temp or die('cannot set contentType');
		my $req = HTTP::Request->new ('POST', 
		$self->{serviceEndpoint}.'/xrpc/com.atproto.repo.uploadBlob', 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json', 'Content-Type' => $contentType],
		$pict)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.uploadBlob): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$self->{content} = $json;
		$ret	= $json->{blob} or die("Err $json->{error}  resolveHandle1: $json->{message}");
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

### Utility subroutines
# make record form message
sub makeRecord {
	my $self	= shift;
	my $msg		= shift;
	my $option	= shift;
	my $collection	= $option ? ($option->{postType}	? $option->{postType}	: $self->{postType}		): $self->{postType};
	my $langs		= $option ? ($option->{langs}		? $option->{langs}		: $self->{langs}		): $self->{langs};
	my $invalidOgp	= $option ? ($option->{invalidOgp}	? $option->{invalidOgp}	: $self->{invalidOgp}	): undef;
	#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$stime) = localtime(time());
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$stime) = gmtime(time());
	my $date = sprintf("%04d-%02d-%02dT%02d:%02d:%02d+00:00", $year+1900,$mon+1,$mday,$hour,$min,$sec);
	my $createAt	= $option ? ($option->{createAt}	? $option->{createAt}	: $date		): $date;
	my $ret			= undef;
	eval{
		my %record  = (
			"\$type" => $collection,
			text => $msg, 
			createdAt => $createAt, 
			langs => $langs,
		);
		my ($facets, $embed) = $self->makeFacetsEmbed($msg,{invalidOgp => $invalidOgp});
		if($facets && ref($facets) =~ /array/i && scalar(@$facets)){
			$record{facets} = $facets;
		}
		if($embed && ref($embed) =~ /hash/i && scalar(keys(%$embed))){
			$record{embed} = $embed;
		}
		$ret = \%record;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# make Facets(URL, tag, mention) and Embed(ogp) from message
sub makeFacetsEmbed {
	my $self = shift;
	my $msg = shift;
	my $option	= shift;
	my $collection	= $option ? ($option->{embedType}	? $option->{embedType}	: $self->{embedType}	): $self->{embedType};
	my $invalidOgp	= $option ? ($option->{invalidOgp}	? $option->{invalidOgp}	: $self->{invalidOgp}	): undef;
	my @facets = ();
	my %embed = ();
	#url
	my $f_ogp = $invalidOgp ? undef:1;
	while($msg =~ /((https|http):\/\/[\-a-z0-9@:%\._+~#=]{1,256}\.[a-z0-9]{1,6}(\/[\-a-z0-9@:%\._+~#=\/]{1,256})*(\?[\S]+)*)/gi){
		my $uri = $1;
		push(@facets, {
			'index' => {
				'byteStart' => bytes::length($`), 
				'byteEnd' => bytes::length($`)+bytes::length($uri)
			}, 
			'features' => [{uri => $uri, "\$type" => 'app.bsky.richtext.facet#link'}]
		});
		## ogp
		$f_ogp or next;
		my $ogp = $self->getOpenGraphProtocol($uri)	or next;
		$f_ogp = undef;
		$embed{"\$type"} = $collection;
		$embed{external} = {
			uri => $uri,
			title => $ogp->{title},
			description => ($ogp->{description} ? $ogp->{description} : '')
		};
		if($ogp->{imgblob}){
			my $blob = $self->uploadBlob($ogp->{imgblob});
			if($blob && ref($blob) =~ /hash/i){
				$embed{external}{thumb} = $blob;
			}
		}
	}
	#tag
	while($msg =~ /\#([\S]+)/gi){
		push(@facets, {
			'index' => {
				'byteStart' => bytes::length($`), 
				'byteEnd' => bytes::length($`)+bytes::length($1)+1
			}, 
			'features' => [{tag => $1, "\$type" => 'app.bsky.richtext.facet#tag'}]
		});
	}
	#mention
	while($msg =~ /\@([0-9a-z\.\_\-]+)/gi){
		my $did = $self->resolveHandle($1) or next;
		push(@facets, {
			'index' => {
				'byteStart' => bytes::length($`), 
				'byteEnd' => bytes::length($`)+bytes::length($1)+1
			}, 
			'features' => [{did => $did, "\$type" => 'app.bsky.richtext.facet#mention'}]
		});
	}
	#my $facet_t = encode_json(\@facets);
	#print "facets: $facet_t\n";
	#my $embed_t = encode_json(\%embed);
	#print "embed: $embed_t.\n";
	return \@facets,\%embed;
}

# get OGP title,type,description,image_url,image_blob
sub getOpenGraphProtocol {
	my $self	= shift;
	my $uri		= shift;
	my $ret		= {};
	eval {
		my $server;
		unless($uri =~ /^(https{0,1}:\/\/([a-z]|[0-9]|[\-\._~:]|%[0-9a-f][0-9a-f])+?)(\/.+){0,1}$/i){
			die("not uri: $uri");
		}else{
			$server = $1;
		}
		my $req		= HTTP::Request->new ('GET', $uri)	or die("Failed to initialize HTTP::Request: $uri err: $!");
		my $ua		= LWP::UserAgent->new				or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res		= $ua->request ($req)				or die("Failed to request: $!");
		my $sl = $res->status_line;
		unless($sl =~ /ok/i){
			die("GET $uri status is $sl.");
		}
		my $html	= $res->decoded_content;
		##get title
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:title['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{title} = $1;
			}
		}
		if(!$ret->{title}){
			if($html =~ /<title>\s*(.+?)\s*<\/title>/i){
				$ret->{title} = $1;
			}else{
				die('cannot get ogp title');
			}
		}
		##get type
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:type['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{type} = $1;
			}
		}
		##get description
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:description['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{description} = $1;
			}
		}
		if(!$ret->{description}){
			if($html =~ /(<meta\s+[^>]*\s*name=['"]{0,1}description['"]{0,1}\s+[^>]*?>)/is){
				my $meta = $1;
				if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
					$ret->{description} = $1;
				}
			}
		}
		##get image_url
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:image['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{imgurl} = $1;
				if($ret->{imgurl} !~ /^http/){
					$ret->{imgurl} = undef;
				}
			}
		}
		if(!$ret->{imgurl}){
			if($html =~ /(<link\s+[^>]*\s*rel=['"]{0,1}apple-touch-icon['"]{0,1}\s+[^>]*?>)/is){
				my $meta = $1;
				if($meta =~ /\href=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
					$ret->{imgurl} = $1;
					if($ret->{imgurl} !~ /^http/ && $ret->{imgurl} =~ /^\//){
						$ret->{imgurl} = $server.$ret->{imgurl};
					}else{
						$ret->{imgurl} = undef;
					}
				}
			}
		}
		if($ret->{imgurl}){
			$req	= HTTP::Request->new ('GET', $ret->{imgurl})	or die("Failed to initialize HTTP::Request: $ret->{imgurl} err: $!");
			$res	= $ua->request ($req)							or die("Failed to request: $!");
			$sl = $res->status_line;
			if($sl !~ /ok/i){
				die("GET $ret->{imgurl} status is $sl.");
			}
			$ret->{imgblob} = $res->content;
		}else{
			$ret->{imgurl} = undef;
			#	die('cannot get ogp image');
		}
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# 
sub checkMagicByte {
	my $image	= shift;
	my $ret		= undef;
	my $jpg		= '^FFD8';
	my $bmp		= '^424D';
	my $gif		= '^474946';
	my $ico		= '^000001';
	my $png		= '^89504E47';
	my $tif		= '^(49492A00|4D4D002A)';
	my $webp	= '^52494646[0-9a-f]{8}57454250';
	my $avif	= '^00000018667479706C61766631';
	my $magicByte = unpack('H32', $image);
	#print $magicByte."\n";
	if($magicByte =~ /$jpg/i){
		$ret = 'image/jpeg';
	}elsif($magicByte =~ /$bmp/i){
		$ret = 'image/bmp';
	}elsif($magicByte =~ /$gif/i){
		$ret = 'image/gif';
	}elsif($magicByte =~ /$ico/i){
		$ret = 'image/x-icon';
	}elsif($magicByte =~ /$png/i){
		$ret = 'image/png';
	}elsif($magicByte =~ /$tif/i){
		$ret = 'image/tiff';
	}elsif($magicByte =~ /$webp/i){
		$ret = 'image/webp';
	}elsif($magicByte =~ /$avif/i){
		$ret = 'image/avif';
	}
	return $ret;
}
# post
# exclusive control. multi-process safe
# return hash(createRecord)
sub post {
	my $self	= shift;
	my $msg 	= shift;
	my $option	= shift;
	my $createAt	= $option ? ($option->{createAt}	? $option->{createAt}	: undef	): undef;
	my $collection	= $option ? ($option->{postType}	? $option->{postType}	: $self->{postType}	): $self->{postType};
	my $ret		= undef;
	eval{
		$self->getAccessToken()							or die("Err getAccessToken: $self->{err}");#start exclusive control
		my $option = {collection => $collection};
		$createAt or $option->{createAt} = $createAt;
		my $record = $self->makeRecord($msg, $option)	or die("Err makeRecord: $self->{err}");
		#my $jsont = encode_json($record);
		#print "Record:\n$jsont\n\n";
		$ret = $self->createRecord($record)				or die("Err createRecord: $self->{err}");
		$self->releaseAccessToken()						or die("Err releaseAccessToken: $self->{err}");#finish exclusive control
	};
	if($@){
		chomp $@;
		$self->{err} = $@;
		$self->releaseAccessToken();
		$ret = undef;
	}
	return $ret;
}

return 1;
