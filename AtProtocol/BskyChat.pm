package AtProtocol::BskyChat;

use strict;
use warnings;
use utf8;
use Encode qw(encode decode);
use parent qw(AtProtocol::Repo);
use LWP::UserAgent;
use HTTP::Request;
use JSON;

use constant {
	##UserAgent
	USERAGENT	=> 'AtProtocol::BskyChat',
	##at protocol
	PDS_URI_A	=> 'https://bsky.social',
	CHAT_URI	=> 'https://api.bsky.chat',
	ACCEPT_LABELERS	=> 'did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:vhgppeyjwgrr37vm4v6ggd5a;redact',
	CHAT_PROXY	=> 'did:web:api.bsky.chat#bsky_chat',
	CHAT_TYPE	=> 'chat.bsky.convo.defs#messageView',
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
	my $chatType				= $option ? ($option->{chatType}			? $option->{chatType}		: CHAT_TYPE)			: CHAT_TYPE;
	my $acceptLabelers 			= $option ? ($option->{acceptLabelers}		? $option->{acceptLabelers}	: ACCEPT_LABELERS)		: ACCEPT_LABELERS;
	$option->{langs}			= $option ? ($option->{langs}				? $option->{langs}			: [LANG])				: [LANG];
	$option->{userAgent}		= $option ? ($option->{userAgent}			? $option->{userAgent}		: USERAGENT)			: USERAGENT;
	$option->{pdsUri}			= $option ? ($option->{pdsUri}				? $option->{pdsUri}			: PDS_URI_A) 			: PDS_URI_A;
	my $self;
	eval{
		if($identifier && $password){
			$self = AtProtocol::Repo->new($identifier, $password, $directory, $option) or die($!);
			$self->{chatType}		= $chatType;
			$self->{acceptLabelers}	= $acceptLabelers;
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
##  override
# getAccessToken
sub getAccessToken {
	my $atProto = shift;
	my $handle	= shift;
	my $option	= shift;
	my $ret			= undef;
	eval{
		$ret = $atProto->SUPER::getAccessToken($handle, $option)	or die($atProto->{err});
		$atProto->getSession()										or die($atProto->{err});
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

###  API app.bsky.actor
# app.bsky.actor.getProfile
sub actor_getProfile {
	my $atProto	= shift;
	my $actor	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (actor => $actor);
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$atProto->{serviceEndpoint}.'/xrpc/app.bsky.actor.getProfile?'.$query,
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(app.bsky.actor.getProfile?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} actor_getProfile: $session->{message}");
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
# app.bsky.actor.getProfiles
sub actor_getProfiles {
	my $atProto	= shift;
	my $actors	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (actors => $actors);
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$atProto->{serviceEndpoint}.'/xrpc/app.bsky.actor.getProfiles?'.$query,
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(app.bsky.actor.getProfiles?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} actor_getProfiles: $session->{message}");
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

###  API chat.bsky.convo
# chat.bsky.convo.deleteMessageForSelf
sub convo_deleteMessageForSelf {
	my $atProto		= shift;
	my $convoId		= shift;
	my $messageId	= shift;
	my $option		= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (
		convoId => $convoId, 
		messageId => $messageId
		);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
			'POST', 
			$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.deleteMessageForSelf',
			[
				'Authorization' => 'Bearer '.$accessJwt, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $atProto->{acceptLabelers},
				'Accept' => 'application/json'
			],
			$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.deleteMessageForSelf): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_deleteMessageForSelf: $session->{message}");
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
# chat.bsky.convo.getConvoAvailability
sub convo_getConvoAvailability {
	my $atProto	= shift;
	my $members	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my $query = '';
		if(ref($members) eq 'ARRAY'){
			foreach my $a (@$members){
				$query .= "members=$a&";
			}
		}elsif(ref($members) eq '' && $members){
			$query = "members=$members";
		}else{
			die("Members is not ARRAY or STRING.");
		}
		my $req = HTTP::Request->new (
		'GET', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getConvoAvailability?'.$query,
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die('Failed to initialize HTTP::Request(chat.bsky.convo.getConvoAvailability?'."$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getConvoAvailability: $session->{message}");
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
# chat.bsky.convo.getConvoForMembers
sub convo_getConvoForMembers {
	my $atProto	= shift;
	my $members	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my $query = '';
		if(ref($members) eq 'ARRAY'){
			foreach my $a (@$members){
				$query .= "members=$a&";
			}
		}elsif(ref($members) eq '' && $members){
			$query = "members=$members";
		}else{
			die("Members is not ARRAY or STRING.");
		}
		my $req = HTTP::Request->new (
			'GET', 
			$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getConvoForMembers?'.$query,
			[
				'Authorization' => 'Bearer '.$accessJwt, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $atProto->{acceptLabelers},
				'Accept' => 'application/json'
			]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getConvoForMembers?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getConvoForMembers: $session->{message}");
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
# chat.bsky.convo.getConvo
sub convo_getConvo {
	my $atProto	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new (
			'GET', 
			$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getConvo?'.$query,
			[
				'Authorization' => 'Bearer '.$accessJwt, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $atProto->{acceptLabelers},
				'Accept' => 'application/json'
			]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getConvo?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getConvo: $session->{message}");
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
# chat.bsky.convo.getLog
sub convo_getLog {
	my $atProto	= shift;
	my $cursor	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = ();
		$cursor && ($param{cursor} = $cursor);
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getLog?'.$query,
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getLog?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			#print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getLog: $session->{message}");
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
# chat.bsky.convo.getMessages
sub convo_getMessages {
	my $atProto	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $limit		= defined($option->{limit})		? $option->{limit}		: undef;
	my $cursor		= defined($option->{cursor})	? $option->{cursor}		: undef;
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		$limit	&& ($param{limit}	= $limit);
		$cursor	&& ($param{cursor}	= $cursor);
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getMessages?'.$query,
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getMessages?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getMessages: $session->{message}");
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
# chat.bsky.convo.leaveConvo
sub convo_leaveConvo {
	my $atProto	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.leaveConvo?'.$query,
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.leaveConvo?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_leaveConvo: $session->{message}");
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
# chat.bsky.convo.listConvos
sub convo_listConvos {
	my $atProto	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $limit		= defined($option->{limit})		? $option->{limit}		: 20;
	my $cursor		= defined($option->{cursor})		? $option->{cursor}	: undef;
	my $ret			= undef;
	eval{
		my %param = ();
		$limit	&& ($param{limit}	= $limit);
		$cursor	&& ($param{cursor}	= $cursor);
		my $query = $atProto->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.listConvos?'.$query,
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.listConvos?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_listConvos: $session->{message}");
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
# chat.bsky.convo.muteConvo
sub convo_muteConvo {
	my $atProto		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.muteConvo',
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.muteConvo): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_muteConvo: $session->{message}");
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
# chat.bsky.convo.unmuteConvo
sub convo_unmuteConvo {
	my $atProto		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.unmuteConvo',
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.unmuteConvo): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_unmuteConvo: $session->{message}");
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
# chat.bsky.convo.sendMessageBatch
sub convo_sendMessageBatch {
	my $atProto		= shift;
	my $items		= shift;
	my $option		= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (items => $items);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.sendMessageBatch',
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.sendMessageBatch): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_sendMessageBatch: $session->{message}");
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
# chat.bsky.convo.sendMessage
sub convo_sendMessage {
	my $atProto		= shift;
	my $convoId		= shift;
	my $message		= shift;
	my $option		= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId, message => $message);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.sendMessage',
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => '*/*',
		'Content-Type' => 'application/json',
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.sendMessage): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		my $a = $res->decoded_content;
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_sendMessage: $session->{message}");
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
# chat.bsky.convo.updateRead
sub convo_updateRead {
	my $atProto		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $messageId	= defined($option->{messageId})	? $option->{messageId}	: undef;
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		$messageId && ($param{messageId} = $messageId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$atProto->{serviceEndpoint}.'/xrpc/chat.bsky.convo.updateRead',
		[
		'Authorization' => 'Bearer '.$accessJwt, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $atProto->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.updateRead): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_updateRead: $session->{message}");
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

# send message by chat
# exclusive control. multi-process safe
# For handles, the first @ must be added.
# return hash(createRecord)
sub sendMessage {
	my $atProto				= shift;
	my $handleOrConvoId		= shift;
	my $msg 				= shift;
	my $option				= shift;
	unless(defined($option->{collection})){
		$option->{collection} = $atProto->{chatType};
	}
	$option->{forDM}		= 1;
	my $convoId				= '';
	my $ret					= undef;
	eval{
		unless(defined($atProto->{directory})){
			die('Not defined working directory.');
		}
		$atProto->getAccessToken()										or die("Err getAccessToken: $atProto->{err}");#start exclusive control
		if($handleOrConvoId =~ /^\@(.+)$/){
			my $did = $atProto->resolveHandle($1)						or die("Cannot resolveHandle: $handleOrConvoId");
			my $convo = $atProto->convo_getConvoAvailability($did) 		or die("Cannot get convo0: $did");
			if(defined($convo->{convo}{id})){
				if(scalar(@{$convo->{convo}{members}}) == 2){
					$convoId = $convo->{convo}{id};
				}else{
					die('Convo members not 2: '.scalar(@{$b->{convo}{members}}))
				}
			}else{
				die('Cannot get convo1: '.encode_json($convo))
			}
		}else{
			$convoId = $handleOrConvoId;
		}
		$option->{collection} = 'chat.bsky.convo.defs#messageView';
		$option->{forDM} = 1;
		my $record = $atProto->makeRecord($msg, $option)				or die("Err makeRecord: $atProto->{err}");
		$ret = $atProto->convo_sendMessage($convoId, $record)			or die("Err sendMesssage: $atProto->{err}");
		$atProto->releaseAccessToken()									or die("Err releaseAccessToken: $atProto->{err}");#finish exclusive control
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
