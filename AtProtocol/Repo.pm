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
	my $atProto		= shift;
	my $identifier 	= shift;
	my $password	= shift;
	my $directory	= shift;
	my $option		= shift;
	my $postType			= defined($option->{postType})	? $option->{postType}	: POST;
	my $embedType			= defined($option->{embedType})	? $option->{embedType}	: EMBED;
	my $langs				= defined($option->{langs})		? $option->{langs}		: [LANG];
	$option->{userAgent}	= defined($option->{userAgent})	? $option->{userAgent}	: USERAGENT;
	$option->{pdsUri}		= defined($option->{pdsUri})	? $option->{pdsUri}		: PDS_URI_A;
	my $self;
	eval{
		if($identifier && $password){
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
		return bless $self, $atProto;
	}
}
# destructor
sub DESTROY {
	my $atProto = shift;
	$atProto->SUPER::DESTROY();
}

###  API atproto.repo
# com.atproto.repo.createRecord
sub createRecord {
	my $atProto	= shift;
	my $record	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})		? $option->{accessJwt}	: $atProto->{accessJwt};
	my $uri			= defined($option->{uri})			? $option->{uri}		: undef;
	my $did			= defined($option->{did})			? $option->{did}		: $atProto->{did};
	my $collection	= defined($option->{postType})		? $option->{postType}	: $atProto->{postType};
	my $rkey		= defined($option->{rkey})			? $option->{rkey}		: undef;
	my $validate	= defined($option->{validate})		? $option->{validate}	: undef;
	my $swapCommit	= defined($option->{swapCommit})	? $option->{swapCommit}	: undef;
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
			$atProto->{serviceEndpoint}.'/xrpc/com.atproto.repo.createRecord', 
			['Authorization' => 'Bearer '.$atProto->{accessJwt}, 'Content-Type' => 'application/json', 'Accept' => 'application/json'], 
			$jsont)
			or die("Failed to initialize HTTP::Request(com.atproto.repo.createRecord): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error}  createRecord: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.deleteRecord
sub deleteRecord {
	my $atProto	= shift;
	my $uri		= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})		? $option->{accessJwt}	: $atProto->{accessJwt};
	my $swapRecord	= defined($option->{swapRecord})	? $option->{swapRecord}	: undef;
	my $swapCommit	= defined($option->{swapCommit})	? $option->{swapCommit}	: undef;
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
		$atProto->{serviceEndpoint}.'/xrpc/com.atproto.repo.deleteRecord', 
		['Authorization' => 'Bearer '.$accessJwt, 'Content-Type' => 'application/json', 'Accept' => 'application/json'],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.deleteRecord): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$atProto->{content} = $json;
		$json->{commit}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.putRecord
sub putRecord {
	my $atProto	= shift;
	my $uri		= shift;
	my $record	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})		? $option->{accessJwt}	: $atProto->{accessJwt};
	my $validate	= defined($option->{validate})		? $option->{validate}	: undef;
	my $swapRecord	= defined($option->{swapRecord})	? $option->{swapRecord}	: undef;
	my $swapCommit	= defined($option->{swapCommit})	? $option->{swapCommit}	: undef;
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
		$atProto->{serviceEndpoint}.'/xrpc/com.atproto.repo.putRecord', 
		['Authorization' => 'Bearer '.$accessJwt, 'Content-Type' => 'application/json', 'Accept' => 'application/json'],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.putRecord): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$atProto->{content} = $json;
		$json->{commit}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.getRecord
sub getRecord {
	my $atProto	= shift;
	my $uri		= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $cid			= defined($option->{cid})		? $option->{cid}		: undef;
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
		my $query = $atProto->makeQuery(\%param);
		#print "Query: $query\n";
		my $req = HTTP::Request->new ('GET', 
		$atProto->{serviceEndpoint}.'/xrpc/com.atproto.repo.getRecord?'.$query, 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json'],
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.getRecord?$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$atProto->{content} = $json;
		$json->{uri}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.listRecords
sub listRecords {
	my $atProto	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $did			= defined($option->{did})		? $option->{did}		: $atProto->{did};
	my $collection	= defined($option->{postType})	? $option->{postType}	: $atProto->{postType};
	my $limit		= defined($option->{limit})		? $option->{limit}		: undef;
	my $cursor		= defined($option->{cursor})	? $option->{cursor}		: undef;
	my $rev			= defined($option->{rev})		? $option->{rev}		: undef;
	my $ret			= undef;
	eval{
		my %param = (
			repo => $did,
			collection => $collection,
		);
		$limit			&& ($param{limit}		= $limit);
		$cursor			&& ($param{cursor}		= $cursor);
		defined($rev)	&& ($param{'reverse'}	= $rev ? 'true' : 'false');
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new ('GET', 
		$atProto->{serviceEndpoint}.'/xrpc/com.atproto.repo.listRecords?'.$query, 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json'],
		)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.listRecords?$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$atProto->{content} = $json;
		$json->{records}	or die("Err $json->{error}  resolveHandle1: $json->{message}");
		$ret = $json;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.repo.uploadBlob
sub uploadBlob {
	my $atProto	= shift;
	my $pict	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my $temp		= checkMagicByte($pict);
		#print "content-type: $temp\n";
		my $contentType	= defined($option->{contentType})	? $option->{contentType}	: $temp or die('cannot set contentType');
		my $req = HTTP::Request->new ('POST', 
		$atProto->{serviceEndpoint}.'/xrpc/com.atproto.repo.uploadBlob', 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json', 'Content-Type' => $contentType],
		$pict)
		or die("Failed to initialize HTTP::Request(/xrpc/com.atproto.repo.uploadBlob): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $json = decode_json($res->decoded_content);
		$atProto->{content} = $json;
		$ret	= $json->{blob} or die("Err $json->{error}  resolveHandle1: $json->{message}");
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

### Utility subroutines
# make record form message
sub makeRecord {
	my $atProto	= shift;
	my $msg		= shift;
	my $option	= shift;
	my $collection	= defined($option->{collection})	? $option->{collection}	: $atProto->{postType};
	my $langs		= defined($option->{langs})			? $option->{langs}		: $atProto->{langs};
	my $forDM		= defined($option->{forDM})			? $option->{forDM}		: $atProto->{forDM};
	#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$stime) = localtime(time());
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$stime) = gmtime(time());
	my $date = sprintf("%04d-%02d-%02dT%02d:%02d:%02d+00:00", $year+1900,$mon+1,$mday,$hour,$min,$sec);
	my $createAt	= defined($option->{createAt})	? $option->{createAt}	: $date;
	my $ret			= undef;
	eval{
		my %record  = (
			text => $msg, 
		);
		unless($forDM){
			$record{createdAt}	= $createAt;
			$record{langs}		= $langs;
			$record{"\$type"}	= $collection;
		}
		my ($facets, $embed) = $atProto->makeFacetsEmbed($msg,{forDM => $forDM});
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
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# make Facets(URL, tag, mention) and Embed(ogp) from message
sub makeFacetsEmbed {
	my $atProto = shift;
	my $msg = shift;
	my $option	= shift;
	my $collection	= defined($option->{embedType})	? $option->{embedType}	: $atProto->{embedType};
	my $forDM		= defined($option->{forDM})		? $option->{forDM}		: $atProto->{forDM};
	my @facets = ();
	my %embed = ();
	#url
	my $f_ogp = $forDM ? undef:1;
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
		my $ogp = $atProto->getOpenGraphProtocol($uri)	or next;
		$f_ogp = undef;
		$embed{"\$type"} = $collection;
		$embed{external} = {
			uri => $uri,
			title => $ogp->{title},
			description => ($ogp->{description} ? $ogp->{description} : '')
		};
		if($ogp->{imgblob}){
			my $blob = $atProto->uploadBlob($ogp->{imgblob});
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
		my $did = $atProto->resolveHandle($1) or next;
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
	my $atProto	= shift;
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
		$ua->agent($atProto->{userAgent});
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
		$atProto->{err} = $@;
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
	my $atProto	= shift;
	my $msg 	= shift;
	my $option	= shift;
	my $createAt	= defined($option->{createAt})		? $option->{createAt}	: undef;
	my $collection	= defined($option->{collection})	? $option->{collection}	: $atProto->{postType};
	my $ret		= undef;
	eval{
		unless(defined($atProto->{directory})){
			die('Not defined working directory.');
		}
		$atProto->getAccessToken()							or die("Err getAccessToken: $atProto->{err}");#start exclusive control
		my $option = {collection => $collection};
		$createAt or $option->{createAt} = $createAt;
		my $record = $atProto->makeRecord($msg, $option)	or die("Err makeRecord: $atProto->{err}");
		$ret = $atProto->createRecord($record)				or die("Err createRecord: $atProto->{err}");
		$atProto->releaseAccessToken()						or die("Err releaseAccessToken: $atProto->{err}");#finish exclusive control
	};
	if($@){
		chomp $@;
		$atProto->{err} = $@;
		$atProto->releaseAccessToken();
		$ret = undef;
	}
	return $ret;
}

# follow
# exclusive control. multi-process safe
# return hash(createRecord)
sub follow {
	my $atProto	= shift;
	my $handle 	= shift;
	my $option	= shift;
	my $collection	= 'app.bsky.graph.follow';
	my $ret		= undef;
	eval{
		unless(defined($atProto->{directory})){
			die('Not defined working directory.');
		}
		$atProto->getAccessToken()							or die("Err getAccessToken: $atProto->{err}");#start exclusive control
		my $option = {collection => $collection};
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$stime) = gmtime(time());
		my $createAt = sprintf("%04d-%02d-%02dT%02d:%02d:%02d+00:00", $year+1900,$mon+1,$mday,$hour,$min,$sec);
		my $did = $atProto->resolveHandle($handle) or die("Cannot resolveHandle: $handle");
		my $record = {
			'subject' => $did,
			'createdAt' => $createAt,
			'$type' => $collection
		};
		$option->{postType} = $collection;
		$ret = $atProto->createRecord($record, $option)	or die("Err createRecord: $atProto->{err}");
		$atProto->releaseAccessToken()					or die("Err releaseAccessToken: $atProto->{err}");#finish exclusive control
	};
	if($@){
		chomp $@;
		$atProto->{err} = $@;
		$atProto->releaseAccessToken();
		$ret = undef;
	}
	return $ret;
}

return 1;
