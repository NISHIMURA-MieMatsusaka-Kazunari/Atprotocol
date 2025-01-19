package AtProtocol::Chat;

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
	USERAGENT	=> 'AtProtocol::Chat',
	##at protocol
	PDS_URI_A	=> 'https://bsky.social',
	#PDS_URI_A	=> 'https://scarletina.us-east.host.bsky.network',
	ACCEPT_LABELERS	=> 'did:plc:ar7c4by46qjdydhdevvrndac;redact',
	CHAT_PROXY	=> 'did:web:api.bsky.chat#bsky_chat',
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
	my $postType				= $option ? ($option->{postType}			? $option->{postType}		: POST)					: POST;
	my $embedType				= $option ? ($option->{embedType}			? $option->{embedType}		: EMBED)				: EMBED;
	$option->{userAgent}		= $option ? ($option->{userAgent}			? $option->{userAgent}		: USERAGENT)			: USERAGENT;
	$option->{pdsUri}			= $option ? ($option->{pdsUri}				? $option->{pdsUri}			: PDS_URI_A) 			: PDS_URI_A;
	$option->{acceptLabelers}	= $option ? ($option->{acceptLabelers}		? $option->{acceptLabelers}	: ACCEPT_LABELERS)		: ACCEPT_LABELERS;
	my $self;
	eval{
		if($identifier && $password && $directory){
			$self = AtProtocol::Repo->new($identifier, $password, $directory, $option) or die($!);
			$self->{postType}	= $postType;
			$self->{embedType}	= $embedType;
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
##  override
# getAccessToken
sub getAccessToken {
	my $self = shift;
	my $handle	= shift;
	my $option	= shift;
	my $ret			= undef;
	eval{
		$ret = $self->SUPER::getAccessToken($handle, $option)	or die($self->{err});
		$self->getSession()										or die($self->{err});
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

###  API app.bsky.actor
# app.bsky.actor.getProfile
sub actor_getProfile {
	my $self	= shift;
	my $actor	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (actor => $actor);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/app.bsky.actor.getProfile?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(app.bsky.actor.getProfile?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} actor_getProfile: $session->{message}");
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
# app.bsky.actor.getProfiles
sub actor_getProfiles {
	my $self	= shift;
	my $actors	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (actors => $actors);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/app.bsky.actor.getProfiles?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(app.bsky.actor.getProfiles?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} actor_getProfiles: $session->{message}");
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

###  API chat.bsky.convo
# chat.bsky.convo.deleteMessageForSelf
sub convo_deleteMessageForSelf {
	my $self		= shift;
	my $convoId		= shift;
	my $messageId	= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (
		convoId => $convoId, 
		messageId => $messageId
		);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
			'POST', 
			$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.deleteMessageForSelf',
			[
				'Authorization' => 'Bearer '.$self->{accessJwt}, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $option->{acceptLabelers},
				'Accept' => 'application/json'
			],
			$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.deleteMessageForSelf): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_deleteMessageForSelf: $session->{message}");
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
# chat.bsky.convo.getConvoForMembers
sub convo_getConvoForMembers {
	my $self	= shift;
	my $members	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (members => $members);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
			'GET', 
			$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getConvoForMembers?'.$query,
			[
				'Authorization' => 'Bearer '.$self->{accessJwt}, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $option->{acceptLabelers},
				'Accept' => 'application/json'
			]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getConvoForMembers?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getConvoForMembers: $session->{message}");
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
# chat.bsky.convo.getConvo
sub convo_getConvo {
	my $self	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
			'GET', 
			$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getConvo?'.$query,
			[
				'Authorization' => 'Bearer '.$self->{accessJwt}, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $option->{acceptLabelers},
				'Accept' => 'application/json'
			]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getConvo?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getConvo: $session->{message}");
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
# chat.bsky.convo.getLog
sub convo_getLog {
	my $self	= shift;
	my $cursor	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = ();
		$cursor && ($param{cursor} = $cursor);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getLog?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getLog?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getLog: $session->{message}");
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
# chat.bsky.convo.getMessages
sub convo_getMessages {
	my $self	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $limit		= $option ? ($option->{limit}		? $option->{limit}		: undef					): undef;
	my $cursor		= $option ? ($option->{cursor}		? $option->{cursor}		: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		$limit	&& ($param{limit}	= $limit);
		$cursor	&& ($param{cursor}	= $cursor);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getMessages?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getMessages?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getMessages: $session->{message}");
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
# chat.bsky.convo.leaveConvo
sub convo_leaveConvo {
	my $self	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.leaveConvo?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.leaveConvo?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_leaveConvo: $session->{message}");
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
# chat.bsky.convo.listConvos
sub convo_listConvos {
	my $self	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $limit		= $option ? ($option->{limit}		? $option->{limit}		: 20					): 20;
	my $cursor		= $option ? ($option->{cursor}		? $option->{cursor}		: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = ();
		$limit	&& ($param{limit}	= $limit);
		$cursor	&& ($param{cursor}	= $cursor);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.listConvos?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.listConvos?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_listConvos: $session->{message}");
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
# chat.bsky.convo.muteConvo
sub convo_muteConvo {
	my $self		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.muteConvo',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.muteConvo): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_muteConvo: $session->{message}");
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
# chat.bsky.convo.unmuteConvo
sub convo_unmuteConvo {
	my $self		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.unmuteConvo',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.unmuteConvo): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_unmuteConvo: $session->{message}");
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
# chat.bsky.convo.sendMessageBatch
sub convo_sendMessageBatch {
	my $self		= shift;
	my $items		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (items => $items);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.sendMessageBatch',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.sendMessageBatch): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_sendMessageBatch: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}# chat.bsky.convo.sendMessage
sub convo_sendMessage {
	my $self		= shift;
	my $convoId		= shift;
	my $message		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId, message => $message);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.sendMessage',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.sendMessage): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_sendMessage: $session->{message}");
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
# chat.bsky.convo.updateRead
sub convo_updateRead {
	my $self		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $messageId	= $option ? ($option->{messageId}	? $option->{messageId}	: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		$messageId && ($param{messageId} = $messageId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.updateRead',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.updateRead): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_updateRead: $session->{message}");
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

return 1;
