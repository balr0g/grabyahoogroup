#!/usr/bin/perl -wT

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use HTML::Entities;
sub GetRedirectUrl($);

my $unmangle_data = <<'EOF';
000:O:q:?::::::s::::n::::b::::$::::Y:::::t::::f:::X::::z::}:7:::c::::X::|:,::{::Q:-:::::::::b:#:y:::.::^
001:::::::X::l:j:::::H:9:::U:X:N::::4:H:x:::f::::l::::::::3::::Y:::O::::6::`:::::m::y::$:::::N:|:l
002::::::::::::w::::::::P:1:r:::=:::::::::b:o:+:::::~:::::y::}::::R::::x:::::h:::::::{:{:u::::::`
003::O::@::::::L::::!:::3:::::4:::::::::6::l:Z::1:::::b:4:X:D::::::y:N::::1:::::::t::::8
004:{::::Q::::d:h::V::$:W::`:R:::?::t:::y::::j::::::::::U:G::::C:::|:!::I::.::A:::+::::~:::::::::t::L
005:::B::O:7:W:M::::::v:::7:A:A:0:T::::::z::V::::7::S:::z::b::P:::::j::8::::::::7::w:::@::`::::,::9:::::6
006::::::*:::::n::g:L:6:::P:H:c:b:::::a:::t:::::v::C::_:W:0:::::r:::::^:h::::::::0::::y:2:::::::,:c
007:8:W::o:}:~:::::%::{::::::::::M::h:::5::N::S::$::%::p:Z::E:::L:j::::::::!::t::::r::::=::::::A::::I:U:v
008::::::::::::J::::x:0::2::::z:7::X:::::K:I:%::::::s:G:::::::::::A::::9:::$:u::::Y::::::::j:::Z:g
009::!::i::|::::::::::a:::d::+:::?:%:8::V:.::^::e:y:f::::::H:::K:Y:i:::::::::q::^::Q:Y:::::::Z:y:::::,:6
010:::::8:?::::8:::V:::G:O:::w:f::?:r:::t::::::::!:::=::f:6:k:::#:::::C::D::*:::::X::::::::v:k::::V:::W
011:::::::::::::::::B:::::::::::::::_:::::^:::::m::O:%:::::::::::M:+:::a::Q::y:::M:::g::`:::9:U
012::::_:w:::::,::r:::::::::::::::q::Y:::e:::,:::::::::A:}:e::x::I:::::::6::::::6:E::b::0:::::h::i:%
013:::::-:::::1:::::::@:K:u:?:::k:N:::::H:r::K:::::::7:,:l::::::H:::::::::::V::V::9:}::::s::b:,:::m:@
014:b:Q:m:=:::Z:::9::::q:A::$:#:::::::::::::1:A:::c:::o:D:4:r:5:::::::3:::B:::::a:::4:::::::j:::@:H:G
015::h:::::@:::::g:K::d::::::::c::::0::2::::K::::L::T:::::|:+:::V::::::o:::s::Z:9::::p:k:::H::R::::::T
016:`:#::::I:2:D::::f:::::1:::::l::::::D::::@:k:::::@:Q:T:8:::::::::::::}::$::::!:::::~::6:::}:^:::A
017::A::H:v:5:Q::1:::j:::::u:::J:::::e:}:::::::@:|::r::::7::::::::s::::v::::!::d:E::H:::o:O::p:::::R
018:x::v:%:l:::::+:::t:S::A:d:::::::::::h:v:::::::::|::::::P:h:{::::8::=:::::9::v::i:O:::|
019:Z::$:::::::::8::P::::g:_:::t:C:p:::::M:::w::o:K::B:::u:q::::::o:::::y:::::::::::1::!:3::::$:::::=
020:U:^:i:::j::W:?::8:K:::9:~::X:::R::::a:o:::::::y:_:::,::=:::L::::::v::::b:::v::2:::::Z::l::V:::::::::*
021:9::::f::=:6:::p:::::::::~:i:3::::::::::::::z::::::r::::z:::|::::::Q:::::::::::F:::v:r::t
022::::4:::::{:::::`:::8:::::::::::::i::::3::::::e::_:g:::::5::v:::M::::::::::#:::A:::::E
023:B:::,:::!:::::::::::::f::::8:z::U:1::G:Q::P::::A:::::::-::::h:?:U:c:::Q:i:::::^::::::,:::w:!
024::::G:~::1::,:o:5::::::-::K:8:::0::::|:::::::^::p:::b::::3:l::_::::R::!::::::::C:J:c:L:_::B:::F::r:::Q
025::::`::B:c::Z:`:::q:#:x::::4::t::u:i::v::u:::*:::O:t::::::^::::u::::M:7::::0:m:::l::::::J::L:2::R:M::::::C
026:7:9::!::::7:z:i:::y:n::k::S:::I::::::y::U::m:::::G:|:4::::R:N:i:::?::::q:::e:J::::H::Q:x:::W::::z::::q::j:s
027:::|:::::::::::::::s:::j::f:L:::::,:::Q:F:V::D::C:9::,:::::T::::::s:*::|::L:w::.:::::::*:::::::#
028::y:^:::y:w::}:6::::Q::V:q::::M:::::::::d:d:,:::::::O:::@::$:::y::X:::N:::-::J::::::::::T:V::::s::e::i
029:m:::L::::w:v::::::*::A:::::::b:F::W::::a:::::::F:S:::9:E:::::::::1:::::T::Y:I::6::|:::_::::e:7::::+
030:*:::::::::W:::::j::!:::::P:K::u:f::::W:F::::::_:::::::p:::::0::R::::,::f::::B:8::F:%::::::::4:::k
031:::::A:a::}:t::::::s:Y::H:l::::::$::::::::::::}:E::::::x:0::1::::::f:::::e:K:::::::::_:::c:::c::h
032:::::::H::::::k:k::::$:W:!::::::::::R:::::::M:::::8:::_:::::F::::d:k::A:t:::::_:::Q:~:Y:`::::::%
033::D:T::::.:%:4:#:::::::::::w::::|:%:::::::::::b::P:6::::::::3:7::::::g::@::::::!:m:R:::::m::8::::-
034:l::::::F:::::::::m:p::~:::b::::_::q:^:1:n:::R::}:K:::w::Y:I:z::3::::::::::t:8:::`:c:^::3::::|::::9:::L:}:::1
035:::::.::::C::^::::E:z:K:::::::::::|:S::o::::G:s::9::d:::::2:C:::::H:8::V::R:Q:Z::::::::u:$::%:d:`:+::i
036::::::U:i::x:.::L:::::::j:::::::::::::::C:L:d:::_:::t:Y::=::::#:G:::U:::B:::F::::v::V::I:e:::4:B:a::Y
037::::B:,:::v::::::::::?:::y:Q:B:::U:C:::::f::::~:`:L:`:q:::n:U::V:::::::::F:,:::::A::w::n:::::D
038:::O::m:::e:H:Q::::x:g:::::d::::::::t:::N::::g::.::::N::::::::f::*::b::::::s::::::::::e::::::2
039::::::::::R:::r::~::n::7:%:::b:::::a:T::::A:u::7::3:::_::w:::::=::::::G::::::::::I::I:::h:p::::E
040::5:::E::::::,:b:*:O:::::::4::::::D:::::4::~::::::c:::::z:E:$:!:::l::0::::::U::w::K:::::::S::E::::^
041:::::::::Q:::{:p:B::O::m::z:::N::::::e:{:::z:6::F:t::::m:::::g::::=::S::I:Y:L:::::::::I:W:g:%:a::::R
042:::::h::j::::G::::r::::v::W::::::j:::x:4:g::::::::P:n:h::V:::::::::::::::e:2::B:::K:::J:::::6:::.
043:+::%:::z::::c:::J:::#:t:x:::::::::s::8:`::::::!:h:::::::m:Z::E::`::=:J:X:#:Z:Y:X:::e:::::D:U:a:l:::::s:.:O:O::::a
044::f:u:::X:P:::::::N:@::N::X::Q::::::::Z:+:H:k::j::::a:::::F::3:w::::::I:::::G::V::::::::=:z:^::::N:q
045:j:%::::W::::::$::::::::@:::$:::9:Z:W::5:::+:q::_::::W:k:c:::::%::::::A:F::::::E::::%:::D:::c:V:M:F::z
046::::::::x:h::::::`:.:::::J::e::::::r:8:B:::::H:::::::::5::::::U::::E:::7:6:~:|:::d:F:?:F::f:U::::l
047::`:f::::::L::T::::::::R::G:::::V::::::T::::::::C:::::::.:::m::9::::h:q::j:o::+:::d::::g::d:e:U::q
048::::::3:g::::W::v:.:::v::::o::::W:+:::O:4::::1:Q::::a::::::::n:U:F::n:{::::Z::j::,:::?::P:::i:L:O
049:::::::::W::`:::::*::v::p:l::::::f::{:O:3:u:::::::4:A::$:H:^:::P:::4:::F::::::9:::n::N:::::$::::%:::8
050:::::0::t:4:::::::T:::::{:D:e:}::S::2:Y:f::L::::.::::k:::::~:p:::^:l::::::6::::::Z::::::::::::::!:Q
051:K::L:::::`:w:::::::o:::::::g::::K:J:L::::::`:|:::::t::W::::::C:::::::%:#:x::7::::v::j:f::::G:h::::e
052:~::::::::%::7:::*:=::::::v:::M:C::w:P:::|::::?::H:0::.:X:!:::V::::::7::c:b:::r::{:K:::E:::J::::1
053:q::::::::::b::L::::i::*:-:::::s:::%:6:::*:::O::::::a:::4:|:4:u:B:::::1:::m:::y:::#::::e:::x:::!
054::B::^::::::K:::::::::::g::G:::::::~::::S::::::E:::::::::D:K::~:::U:::::::,:T:e:::::U::N::X::E
055::::*:::::p:::,::{:O:::z::o:::::::4:S::::O:d:{::S::::::A:m::`:::::L:::E::::::::E::k:T:::::W:H
056::e::e:e:::i::t::::|::::*::::i:::::#:2:F::X::::H::::v:$:=:j::::k::::T::::-::::*:G::::::z:X:R:::G:::::X
057:::P:::2::t:::L:D:::e:C::C:::x:::n:::6::::::U::::n:*:::*::k:::::?:::O::5:::6:e::::!:*:::$:::=:l::-:@:::K
058::+::j::::::::::h::::I:::::3:X:::e:=:d:0:::::C:::::::D::H::::::::@::H:j:::b:A::U::::q
059::s:::T::::::O:#:~:::::::::h::E::::?:::$:P:::::::::::0::s::::::d:U:::T::::b::z::C::::::o:::x
060:P::-::::::-::::::?:::f::::::|::K::::J:b::5::::T:::I::e::?:R::::v:A:::::::::O:L:::::::d:8:::?
061:s:}::::::r:f:S:::::::e::|::::m:::.:::l:::0::::::::M:::s:::P:G::+:::::J:?:2:::+:::E::::::::::::y::m
062:::`::+::x::::c::::::::::6::::::n:::::::::b:::::::^::*::b:,:::::H::::::R::*:}::R:^:f:::,:N:i
063::j::M:{::::F:::o::::::::^::B::C::::::C:::=:}::::v:::@:o:::c::::E::::::z:q::H:::::::::::::W:m::+
064:^:d:::::::B:l:v:G::G::::::E::::::j:::?:::::,:T:U::::*:U:::::1:::::9::d::d:::N::::::::::::::::}
065::C:::::K::o::!::::N:::7::Z::+::::::::::::::4:::h::::l:::::T::g:Z:,::L::7::c::::::::T::`::::::N
066:::s::U:::I:n::S::::o::::::k::1:::|::::n::2:~::7::c::B:::::X:k:::::::`:::::I::::::::::::::::}
067:::::1:::k::k:Y::x:::y:=:j::::m:~:::::::::::T::=::%:w::0:Z:::::X:::::::X:::::::=:::::p:::9:Z:K:::8:-
068::X:Z::R:::F:::::3:::::::3:::::::::::::T:::X:::::c::::::::::y::P:q:::i::::7:::::.:S:::+::*:B
069:::+::C:::^:T::::::::U::::z:L:T:::E::::E:::#::-:::N:3:::::::::9:1:::z:C:S:8:::::::::5:::::::o:::::J
070:e::::P:=:::::::::B:::::H:::::::Q:4::::?:::W:::c:::7:::Z::G:::::::B:B::z:k:^:_:t:::::::x::4:e:::D:H
071::n:A:::4:::::::.::::::p::H:O::9::`:X::::~::C:::::Q:2:@:::::::3:::+:W:W:l::::::::::::M::::::::::{:_
072::::::g:m:Y:m:::::::H:G:`:%:::j::W:::::`:v::::Y:e::::::i:::}:::::::::::r::D::::n::q::l:4::X:5::Q::::}
073:%:H:{::::E::::::4:E:z:%:::::e::9::::o::::::::8::-::::::::o::#:0:H::E::::::h::l:::J::!:::::::6:$:i:X:m
074:::::z::0:::::+:W:Y:::z:O:t:|::%:::::::::::}::::J:f:e::v:*::=::A::o::x::A::v:::H:::::!:z:::::::::::::B:::::::O
075::u::E:::D::O::z::S::w:::::+:::::::::::+::::::#:n::=:::::f:::::::::::k:4:::::r:n:U::::x
076:::::::::+:E:Q:U::::N:J:::B:::J:.:::~::::c:^:b::3:u::::_:::::::A::-:::f::::::n:}:B::::=:::B
077:F:?:::::#:::e:+:u:1::::s::::a:R:P::@:::::a:_::N::k:::::z::::h:::Z::~:::::::y:o:k:t::S::::::e:9:::8:::::y
078::::l:n:M:::::::o::::::+::::::3:,:^::p:::N::w::::M::::#:B:t:::|:#:}:::7:::::R:::::I:j:8:e:h::::::g
079::::::::{:X::q:::::::a:h::::::X:x:::D::x:::B::::,:::+:::S:::l:::5:w::::*:e::::k:~::G:r::+:::::q::::S
080:::d::J:::::::v:z:^:::::::0::V::::::::::::s:y::+:*::y::::::::::2::m::2::z::P::o::::::4:5:::0:X::V:c:c::A
081:v:::2:F::8::::d::::M:::::::::{::::b::::-::::Y::q:m:h::::::::g::::::::*::::::::9::::::::::z::F
082::x:N::i::q:.:8:::W:::::::::::::::::q:u::H::::q:::::j::::::::V:::::::::f:B:j:_:X:::u:%:::*
083::P::J:::I:::::::2:b:::J::::*:L::.:B:+::=:::z:::::::^:5::F::y:::::q:o:$:::k:::::o:c:3::::j:::T::::#:V
084::7::v::,::::3:::R::::::::|:=::::W:M::::::::X:::::::::::I:::_:@:::K::=:::::=:s:S:m:::::::::4:r:s:G
085:R:::W::9:::_:b:M:::3::::9:::::::::::W::::r:::::Z:o:::?:A::::::::C::::::K:E:=::::::9:::::q::J
086::::::w:*::::A::::::::E::::::c::k:::::7:o::::+:^::B:::::~::F:::::6:::::C::::::*::r::::~::::b
087:4:::::::::::::7:J:::::::::_:::::::v:~:Q:7:::P::l:::::f::::O:::t:::+:_:::}:3:w::s::1::::4:s:t::::3
088:.:::::::::::s::z::::::::U::::$::::y:p:::@::::l:::::=:::U::Z::#:::::+:::::_:5:::::::::Q:2:=::::x::m
089::_:M:5:6:L::::::i:::::%:=::W:::::U:1:v::::9::9:::::{:Y::::::::W::U::`::^:::i::::::::Z::i::::K
090:::~:::Y:s:::::n::-::$:4:::K::::`::::::X:::::::Z::U:g::`::::+::1:::J:M:W:8:h::::W::::::H:@::::::::n
091:n::r::Y:.:$:::D:::::l::}::::C:o::d::#::::K:g:::::::::8:P::b:::|::::::::6::1:::::r:::::::n::f:=::e:W:::n
092:::::K::M:::G::!::R::L:::::::y::E::!:8::}:5::::::*::F:X:V::M::w:b:::,::j:*::::~::::::::::::I
093:W:::$:b::::::::::C:6:::::S::::::::::::i::a::@::::D:d:|:`:::m::::P:::.::::::-::$::P::D:U:::^
094:::::::::::::h:::{::B:L:::::::-:5:~:_:l:::*:::::::::W:::!:~:::k:H:a::N:1:X:::::f:::e::A::::j::::2:P:F
095::::Z::8:L::::::I:::4:::::::::`:::::::o:::::v::u:::2:::6::x:A:w:a:@:E:::::}::::::::::8::::::T
096::::X::v:::9::::::::::$:,::@:::::R::w:.:::R::l::=:~:::u:+:5::::::::::::a:::::::::::::L:8::_:::k:~
097:::::G:::y:7::6:1::::::::A::9:::v::::u::j:::::E:::::::::l:@::l::N::::::}:!:0:::::a::::::::::1:=::d
098::::c::::a:::9::c:@::::y::::v:::9:::.::q:i:}::::,:::::::6:::`:v:::::::?:::5:::S:::::::7:::::p::::A
099:::::s:J::::::*::::::i:::}::::o::S:::9::::::0:::#::T::d::D:::{:::::-::H:::=::::::0::R
100:A:T:::X::`:::O:y:p::d:y:::::1:::*::*::?:Z::s:::{:::a::::R::f::.::::-:j::5:O:::x::Z:L:n::::|::::z::7:::3:t
101:T::@::#:N::?::n::::::::+::::C:=:u:0::F::::D:i:u:H:::i:X:0::::8:::p:::z::::::N:s:::::::::::G:2::*:%::d::I
102::::::::c:R:w:::0:i::g:Y::}:::$::T::m::Q::7:l::::::W:.:g:::::I:::!:::6:V:3:G::e:::|::Z:,::$::::::E
103:H:::::::G::::::T::::}:::`:::R:^:P:::!:h:,::O::::::::::f:::.::i:::::::::::::x:::::::P:Z
104:::p::::U::::::Q::Y::{::::B::::::_::N::q::::x:i::::y::{::e:::::::::?:n:f::B:K:::?:N:::b::::::::`:_:::N
105::::w::O:f::::::=:l:f:8::V:::u::h:::i:g:::::::::v:~::::::::::z::A::r::s:_:::x:m::P::b:g::::::::::::U::::::.
106:_:::A::::::::::::::!::::!:w::#:d:P:::::L:Y::::4::::-:::::h::J:::1::u::O::::::f:H:::S:}:N::::::::.
107::S:8:::::0::::::::::::::::f:K:b:::P::T::::=:5::::`:B::`::::C::::::y::w::::::::U::::::S::$:::^
108:::7:g:::::Y:g:::j:+:Q:::Y:y::P:::::::f::::::g:D::N::::::::M:::::t::::::g::@:q:::4:R:::::::x:~:}::R
109:!:U:::::::r:::::0::B::e:5:::F:a::::::5:D::1:2::::::x::::::4:::@::u::::C::9:::::::,:7::::-:p:::::w::p
110:Y:::6:q:^:::|::H::::8::~:b::k:::::,:::o:::::G:s:::S:R:R:::::s:::Q:::,::::::::::::T:::::::n:::::~
111::N:::::::::::E::7:b::1::Y:::::1:::K::H:G::B::::R:s:::::::T:O:::::#:-::::O::::5::w:F:V:::::t:=::::::2
112:X:8::s::C:o:H:6:::::::::3::::::w::6:::::8::-:`:1:::::::p:+::9::i::Z:::::^::H::M:::::::0::u:::::T:::C
113:E::a:Q:::R:::J:I:::j:$::g:t::h:9:::*::::w:::::h:::I:::j:::~::b::q::::f:::::W:::::::::g:i:Z:q::::S:C::b::K
114:d::t::::C:V:#::@:}:::::C:L:a::::::p::::::7:X::8:}:T::D::}::q::T:L::I:::::::::::i::h::l::::!::N::::0::x
115::::p::::::0:?:d:Y::::::::::v::M:::::^::::A::V:::q::::::^::^:::X:%::::::l::I::-:_:::::m:*:::y:z
116:5:::::n:::::::8:5::::2:::@::::::::::!:n:::J:J:g::r::L:X::F:$::::5:.::::p:::O:o::::.:2:G::::::T:1:Y::-
117:::Y:V::+::::::P::::::T::b::::}:V::@::A:|:::::R:f::S::::a::Y:::::::::::D:G:::::L::::::-::::D::::5
118:::4:8:$:::-:::::::Z::*:::I:::::::::::u:::n:::::}::::9:::m:M:::e::::E::0:_::::b:M::s:Z:5::::::v:::e
119:::E::W:`:::U:u::::F:::::::::`:Y::F::::::::N:::y::6:-:::u::8::::c:S:::i:::C:=::2:1::::::{:|::::::::,:=
120::K::U::::::::::::_:::b:u::T:p::::::|:::::::::::+:e::::7::::::x::p:Z:::-:::::::::g:3:R
121::::f:2::::::x::?:::::o:9:::d::5:t:L::0:::::::d:L::b:p:::y:::::9::4:Z::::::j:E:y:::::::p:y::+::3:::J:|:B:,
122::R::h:::::*:$:::::1::Z:::U::E::::A::T:1:*::::a::::::::^::::::::3:u:p:::@:::::r::::Y::0:?::3
123:g:E:::::::::::2:::::n:0::Z::E::f:::::::E::::::::v::::::::.:::4:e::::=::g::u::::q:::::::::P
124::::C::E:::::m::::S::::::::-:z:6::}:::::s:::b:-:::K:::::R::::::::w::::::F:::e:U:P::o::::@::Z
125:w:Z::}::h:::K:::x::::::::::::::D::::::D:::::%:::1:::::,::D::9:!::::|:::.:T::Q::::a:c:H::::l::,:Y::D::1
126::::7:*::^:::_::5:::U:3:#::P:y::f::e::::m:@:3::|:V::{::a:::::::G::::::1:~:::s:::::::k:0::C:::y
127:::::r:q::::::::::::E:f::V:k::6::O:::o:::J::::::::#:}::a:::::R::B:+:::R:::p::g:D:$:::::~:#:::i:::u:::4
128::l:::::::::::D:::D:h:~::6::::F:P::::::#:::G::::J::::1:Z::q:::G:::::,:::3:::::::::::}:::-:O:::::3
129:::::::::D:H:.::`::k::::::*::::::O:@:E::::x:::::6::::B:::t::::o:::::t:::P::%::2:::::::::::::,:k:G
130::v::::A:u:#:::e:l::::::.::}:h:q:q::?::N:n::::::P:i:K:d:2:G:V:Q:::o:::r:w::::::::::::p:%::::a:G:::_::I:.:Q:::V
131:::x:::f::::::4:%::p::::::5:y:S:::J::::::+::::w::!:::d:::::-:::u::D:l::::n:::4:U:0::::::9:B:O:?:::v
132:D::K:.::i::q:P::k::d::#::Q::::::d:::::`::::::=:::6::$:::::9::::::::::U:G::{:::6:y::f:::Y::6:::@:^
133::::::::E:::::::}:::p::::::H:B::::+::::::::0:5::L:R::Q:::?::::::+::::::::y:::~::::::::3:::::f
134::::~::t::B:::::a::2::k::::::::::::J:::::L:::D:::::M:*:u:B::h::.:Y:8:::m:P:D:::J:::|:3::=::::::::7
135::::::@:::::::$::L::::V::::U:::::U:$::::!:::::::%::::::::D::n:::::::$:::::A:@:::2::::::d::::7
136::::::::U:::::@:::r::::::_::s:::::X::::t:k::6:::::4::::::{:::::#::::::O::z::o:::::k:::7::::7::j
137:C:::S:::::G:M::I::::::8::5:::+:I::^:::9:e:?:::::::H:-::::::::::::::::::n::p:3:G::W:::#::a:r:::6
138::$::K::!:l:8:::|::,:,:::::x:::{:x::::E:6:::I::::N:::::F:::::O::::P::::::4:`::G:@:G::-:9:H::::::Y::::*
139:::w:0:^::::3:q:::::.:::::::::::::::Y:::H:::`::u::~:I::::::::r:::m::::#::::N:9:z:0:#:_:::U:::7:I:w:::~
140::::I:::::^:a::6:::::::::::::::9:r::::::::::A::r:::::::V:*:s:::::y::S:j::::::::,:q::r:::F:n:9:4:Z
141::1:::::::c:::-:Z::::::::n:G:::{::`:G:::0:::M:B:n::::::C::2:Q::::::::g:::::6:?::g:5:d:::N:::X:::q
142:?::::::::::::::::|:0::l:::.:m:y:::#:::J::::%::p::|::::::::5::G:c::H::M:p::::::8::::+::::q:a
143::w:::Z:S:T:S::B:F:B:A:r:P:!:::q:e:::o:o:::::::{:C::::M:U:O:::::::::4::::::t:::::_:`:::F:A:::::~::F::::B:s
144:0:|:Q:::::T::::k::a:::j::z:::::::::::,::::i:::::{:|:::::e:::::9::::j:s:::::|::`:4:::::p:k:C:n:::`
145:::::?:::::Y::=::o:::f:|::::::::::7:::::g::P::s::n:::::::Q::_:::::::::::f:::::::::^:6:.::A::T
146:::::@:-::::::::u::5::::#:::::::*:I:h:Z::=:f::::::!:::::::r:::B::::::::,::$:::::::S:J::::::=:v
147::z::+:::?:p:::a:X:O::::6:::L:::5:%::Q:$::m::::0::p:::1::n:::::::T::::::_:3:::g:::::V::::E:::?:E::|:*
148:::::::6::g:r::::::::::::::Q::::j::::::::*:f:U:::S:::n::::8:t:::K::::::::::v:::::^::::R:::G
149::::::V::o::::3:::t:f::M::T:K:~:::m::::::::::::x::%::::::v:X::::::::9::::!:::^:::::::Q::h
150::::d:::::::::f:w::}::::.:=:::P::p:3:::L::G:?:::::::::l::6:U:::e:^::}:n:v::$:-::9::::::n:::n:::%:::{::b
151::L:#:::::*:I:::N:::::P:,:C::L:#::::!:c:::::{::::::W::::::::::P:::::D::0:::C:8:::::::::O:V:::::::?
152:::U::p::::0:::C:u:m:::::.:::2:::G:t:.:::b::V:`::0::::::p:::::H:S:::::d::::::::X:W::::::{:::::::?:r::c
153:,:::1::l:::::X:::::j:::^::::::J::::::::::Y:m::$::::::::%::H:N:b:_::7:z:::c:8:5:$:}::7:::::?:Q::::::w:::::::::v
154::p::x::d::m:::*:M:::::X::::::j::b:q::g::::%:a::::::~::s:}::r:::::::::::::1:~::::::::::K:1::::C
155:::::::::::j:R:7:::::{:8::!:0:^::::%:z:s:::a:::::?:::3:::V:%::u::L::w:::r:!:::3::::::::L:::C::8:f:::::o
156:::::::N:::C::::::::::::::::::s:K:::::::::::::O:#:g:X:*::::M:e:::::o:::T:x:::B:L:::::!::s:5:::1
157::F:::::::::::^::::::::#::X:^:g:::^:::h::::::::d:::g:C::::a:r::p:::%::M::::i::::X:u:f:::g:::z
158:3:c:V::a:::n:::3:T::y:^:::::::1:s::R::::-:::c:n:4:::O:::::::+:::::a::::L::3:a::%:::d:j:::::l:W:d:W::j
159:::::_::::k:::|::U::S:::S:R::::G:_::B:c::_:::M:J:::7::N:J:$::T:0:::`:t:::^:Z:::::::#:{:::::?::b::M:j:::o:2
160:y:=:::9::::S:P::9::I::::q:Y:Q::::::::O::%:::::::!:::::::C:g::::@::,:u:e::::::::O:=:O::5:^:::::}:H:G:5
161::I:I:3:D:::z:::1::::::V::@:=:-:::::::::V:t:::9:r:::::O:O:u::::::::::::h:7::::::::-::h:k:E::D::::::8:X
162::::::u:A:::::::::U:::::,:::::G:A::0::y:Z:::m::::A::::S:3::5:R:Q:{:::T::N:V:^:*:J:|:W::::::M::f:-:::K:-
163:=:::k:::O::e:m:V::s::u:::::::::U:Q:::::?::::.::::B:::A::$:::J:::e:$::C:::L:::::R:a:::t:w::::::T:D:M::Q
164:::::::::y:::y:::F:`:::I::q::::2:n:L:::::::::{:::::::L:::L::::k::r::P:::::D::::^:::m:.::::P::8:::a
165:o:::t::::::2:C:@:M::::^:%::::?:::::::Q:g:::::::C::::::::::p::n:_:::J:%::f::`:::T:g:s:A::::::P:5:::::P
166::a:!:::T:::::w:O:::n::::::c:K::::::A::::::::::::::::::::N::z:g:::::::::#:::J:::::}::::U:Z:C:a
167::::O:j:F::,::::::::2:c:F:O:::::::::B::::::::t:{::y::::::?:N:7::::m:i::::::::F:::::-::::T:::::{:p
168::::::::u::f::::4:::::J:::::::z:::::::::Z:::w::m::i:::P::2:::P:::Z:::c:m:,::8:::::::C:::4:*:P::::r
169:#:6:::::a::::}::::q::y::T:::::$:::::::::6:::::::::6:z::::::::::::::::::::::::i::m:5::::0:R:l
170:::::::h::A::$::G:C:::::=::::::w::r:::=:::|:r::9:::::!:::::l:U:::E::_:O:w::U::::O:::::::+:m:::m:::::q
171:::X::N::p:b::%:::5:6:D::2:c::::x:%::H:C::::::$:s:::::::::b::d::::E:::::::5::y::^:::K::::_:::::.::3::::::m
172:::=::%::n::::r:::V:I::::i:V:.:::::3:7::::S::::::::@:H::::J::$::::::g:::I:A::p::::::::-:r::G::U:N:::H
173:J::::::::E::::::5::+::e::::::x:::::::B::I::Z::8::::J::a:::O::::o:::::::-:::1:::::::::::Q:+
174:M:::::R::!::?:::b::|::?:::::::3::::::::l:::I:O::::o:#::i::::*::d::F:::{:S:.::::::D:r:4:::::::::::_:::o
175:::::t::|:2:a:::::K:0:-::k:::O:V::::5::_:::`::::::F::,:::U:::::::::::T:i::E:`::k:%:::i:::::h::w:w:?::Y::::::::G
176::i::::::::p:o::F:}::::l:::^:::x::e:::::z::I:::o::::k:3:::::::p:I:::::A::::#:L:@::::j::t::::z:#
177:::j:::#:~::::::e::::::::::@::::::C:m::::?::e:::::?::::::}:z:::M::2::o:::A::l:l:::h::v:::K:::::f::Y
178::{:g::4:H:::J::::N::%:0:L:::M::D::y:N:::::2::::D::::I:::::::::q::m:l::P::::::D:N::::::m:::G:u:I:B:~:^
179::::::::Z::N:_:Z::c::l:::6::~::Z:::4:H::::@::::w::::X::::::S::w:::`::.:a:T:::S::S::#:::?:C::@:::::L:@::N:S
180:h:-:y:r::G:b:::}::::::R:::Q::::,:,:::u:k:i::C:d::#:z:j:::::::::::B:`:::i:2::l:::::C:::R:5:}::::::::::j::b:o
181::b::?::::l:::-:H::::::6:m:9::w::::h:l::*:::m:J:K::::::N::G::::::::W::::::::::::1:M:Q:::,::::::x::$:!
182:::q:u::k::|:::E:::::::U:r::::#::::{:e::::::E::B::7:::f::!::::N:Y::}:::n:Y::::h:c:::u:p:::::::#::::t
183::2:::H:x:::q:::::=:+::o::::U:::::Z::C:R:::::::^:u::5::::?::::=:::::h:{::l:_:U:{::::?:::T::5:3::J:b::y::M:0
184:::::::e:3:V::::::::E:::::J::1::::::::::z:#:@::::::::j:::+:4::?:::::::::m:*::d::W:2:s:w:::::1::::@
185:$:g::n:c:::j::::::::::5::q:::_:q:}:N:::x::%::_:::::#:::::::n::L:::-::::::::::M:::l::7:::S:c::p:::u::g
186:::,:N:::::i:::::H:4::x::N::2:5::g::::::::::x::::::::::::::::2::c::::W::::::::::*::v
187:|::::::y:+::::h::::T::::v:::::::::y:::3:::::::::K::,:::R::+::::::`::::4::q::::::::::::2
188:::::::::::::m::v::::o:F:::F:::w::*::-::::::Q::::::x:1:::o:::::3:::::r::?:::j:::::::::B::::J::::::::::V
189:t::::::B::M:V::::::e:T:::::8::0::::!:::::::4::3:::?::w::B:G:::::d:::9::::::::+::{:::c::t::X::i
190::::::o:Y::.::::::_:::::g:X:}:R:::u:::::::::::::i:::s:.:5:::::R::{:::5::::::H::::B::::s:.::v:%:n::::::s
191::::R::D:::::=:z:::R:+:9::k:::X::::2:p:::U:::::_::$::::x::%::x::_::*::Y:::::::::i:::::v:::#:::::5:M:f
192:::e:#::m:::::g:_::9::t::::4:::{::::1::z::2::4:X:::::1:9::::::^:::::.:::f::::v:::u:2:::X:$::::s:::::x:9
193::,::D:o::::::::|:::::u:#:s::M::::::i:::::::::::8:j::H:::::::%::K::z:~:#::::::q:{::x:G::::Y
194:r::5::u:c:,::::{:7:P:::w::Z:::s:c:4::::J:}:::M::::n:$:::L:::-::E::::::h:T:::$:::::d::::x:O::|:%::B:::::o::1
195::::::::X::::::::::w:?:G::::S::M:,::G:I::t::::3::::::.:::d:!::::q::::::|:w:::::::^:@::::|::::#:::Z
196:2::6::y::::::::::a:@:,::G:O::::Z:7:::::o::Y:::::k:x::Q::E::!:::::2:::0::W::T:t:U:::m:p::::=:::::k:a:_::|:I
197:p:::T::1::L:::::B:_::v:m:D:::::H:::{:::k:::F:::A:::::K:2::::::8:~::::x::::u::P:::::Q:::x::::::-:::7::m
198:::W:::e::::::::::u::::*::^:i::::::::::Z:W:5::j::z::::::1:v::K:p:::::::::u:::F::::4::c:::::_::K::E
199::::::::h::x:::::::::!:m:{:a:O:::::d::::v::%:|::1:K:::::v::::::b:r:::::B:d:::::::::::L:::k::f::r
200:k:3::y::6:S:9:2::P:::::E::-:::::::A::d:L:::::::v:N:2:e::i::::*:::~:W:::p:}:::b:::B::::3:::B::`:::::W:c::3
201::::::::5:::N::::::R:::::g:::k::=:{:c::::::::::::::::H:8:e:::s:G::$::::v:r:::P::::t:w:::::::j::t:n:::::::o
202::k::::b:+::`::::::::::::8:::!::T:V::::R::8:+::.:e::::::p:::::7::*:::q::~:@:::::::::}:::::::Z::::t
203:I::H:::::$:@:::F::D::::::::::::::3::!::::d:~::w:::D::::q:i:::d::%:S:j:::::::::::::x::::C:v:!::~:L
204:6:::::::::Z::::~:h:Z::::::6::::::::c::::-::::::::::::c::u:S:::|::r::::::b:M::o::y::::::u:::%::#
205::::::::::::%:::::_:::::.:::::::}:::::::g:::::::q:::x::S:Y:V:v:::::::::J::C:::Y::::P::|
206::::P::::P::A:::::X:?:D::::::::O::-::::w:::m::::-::::T:D::y:::$:::::#::::::::::b::::O:::::r::::H
207:::*::M:::::7::::::=::::::::::::X::Q::#:X::F:h:G:P:E::1:7:r::::d:f:::::::::::7::.:7::@:3::::y:6:L::::o:::a
208::::::%:}::N:d:4:.:T:b:::5::-::7::D:::*::::::W:w::::::+::::K:W::::::::::::J::::::Y::~:6:6::w:0::::g:::{
209::::z:3:r::::~:R::::::.:::2:d:|::l:!:I:::::A::p:::::::::::::}:::::::R:::b::::+:6:W::::::d:+::::k:::5
210:i:::q:::{:::=:B:::g:3:::4:Z::m::r::::::~:::q:S::y::::::::7:::9:t:n::::?:::.:?:b:a:,::X:::::::Z:::C:y:z::d:D
211:::k::L:::::::Y::1:m:::::n::u::h::::+:::.:U:::::8::::C:::::::b:::::k::::::z::K::t:+::`::E:::g:b::::6
212::r:_:9::Q::_::|::q::::I::::$:::A:::s:::#:p:::W:2::::j:::%:v::::::::::Q:o:a::l::::::G:::1:::o:::::A:$
213:}:~::m::0:k::b::K:::W::7::::D:::Q:-:8::::I::}:M::::::?::2::0:::b::J:2:L:0:::I:::::::::q::{:::A:::_:::E
214:::h:::::::U:::::!:s:::D:::`::#:::::b::::1::@::V:::^::S:U:k::#::c::::t:`::%:N:::::::I:K::::7:::M
215::0:::::v::::::-:::d:::::::::-::::::::q:c::::m:::J:V:::W::::g::::Y:::::::::::b::z:::::::f:S
216:::z:::::O:::D::#::::::`:::s:::~::::4::O::j::j::::c:::::,::2:::::|:::::::I:::::::{:r:P:::::u:::+:W
217::*::{:::-::::::U::K::S::F:::7:2:::0::::::p:$:::::h::::::::D:::y:Q:z::@:c:::|:::}:4:::c::::F:}:::o:::4
218:::::::r:@::::::::c:::::A::::i:::y:7:::8::5:::9::::::::::::W:::G:::::::::::::::X
219:c::c:::p:%:::s::::f:{:h::::C:::::n::::::::m:*::::::::::c::t:k:::J:::V:K:::::::::h:::::q::{:::?
220::::::::::!:::H:::q:::::::n:::S:b::B::::,::::::::::-:::::::i:::::n::::::{:P::::d:1:D::::::::L
221::V:G::k:{::::T:::::::I:^:B:a::::J::@::::B:Y::^::2:::::a:|::::-:n::::::::::P:M:::::k:u:z:::W:::::::F
222:::C::=:::A::^::t:!:s::::::::::4::k::p:%:A:W:::t:h::z:G::::::::::X::~::::::::S:::N:L::::::!::V:::::J
223::4::Y:::_:d::::m:::::H:::::N::@:::::::r::c:::#::k::p::n:y:::=::q:Q::f::8:::::Y:::::::N:::.::n:::::#:v
224:u:G:S::7:::::::`:::G:::::::Z:W:D:I::m:9::::::e:::m:i:f:t:W::{:::f:::K:::::::::::::::w:#:C:::::::p::A
225:::::::z:f:::2::+::::M:d::::Y:|::::T:R::6::h::::::V:::`:N:~:::::C::{::5::::X:::::`:i:`:k:J:::::A:Y::K::u:z
226:L::D:::$:J:::::2::%:::l:::::,::O::=:::j:$:-:j:::u:::::Y:F::::a:M:::::B::+:::::z:h::v::V::::::::{:l::D
227:::::V::d:::::::::::::r::::::r:i:::P:f:5::::::::::K:@:M::B::F::::a:::y:::::T:V::::::Q::::J::::l
228:::}::`::::u::::::V::W:W:::E:I:::r:~::$::k::::::A:::::::h:N::::k:J::L:q:j:u:R:5::2:::@::c::.:K:::::+::$:::::@
229::@:.::g:::R:::s::_::-:F::@:::::8:::c::-::z:U::::+:c::y::S:w:,::{::7:g:m:::s:::=:c:Q:::1:::::::9:h:::~:::0
230:f::::|:::N:::::w:t:::::3:j:r::::j:::N::::!:::::5::J:x::Q:::::f:a:$:j::o:::::::::D::%:f::1:o:::::::a::R
231::J::::::J:::i:::::M:::w:S::::A:::h:::::::::W::`:::::::F:S::j::::X:::}:+::3:a:::::::::::0:x::S
232:z:m:F:::::s::I:J::X:A::P:::::::Y::d:::::F:=:`:L:::::T:::::::::::::::::K:::1:M:::::::::j::::::d:y:|
233::o::::s::::::Q::::::::::::2:::::::::::::::::o::::m:W:::i:::Y::::4:%:R:::::+::E::::::A:::9::u
234:1::n:::Z:3::~:F:::::c:n:a::n:::::::?::::::::::k::::l::z:t::::::::?::x::::0::::I:e::S::7:!:u::::F
235:::l::5:::::*:::::::::,::F::::L::::::Z:::0:E:::::::%:2:::F::::O:::3::::Y:::?::::.:*::::::::::@:::::::g
236:::::::::::::C::,:::::7::p::K::::::::::U:9:R::t:t:::I:c::::::::::4::::V::.:d::h:S:::::c::2::::I:`:M
237:::R:a:S:_::::-::A::p::1::::::::~:D:::l:::::::*::::::::G:::d:0:6:::::::::F:::::::::::::o::{:O
238::::F:::::$::#::::i:::::t::H:l:+:::G::::e:x::F:::l::::M:::Q:@:K::M::D::F:=:::K:::::::::::::I::::::?:N
239::::|::::::X::e:i:::::r::N::n:6::::a:::@:s:.::::::r::{::|:_::A:::I::::%::x::v::W::::::::O::A::`::O:|:1:n
240:::::!:P:9:=::5:f:::::X:::{::3:::::::E:::E::::q::::C::::o:v::,:::x:::::::::::::%:N::g::t::2::::::P
241:N::::B::V:C::4:Z:c::M::i::h:g:::S:I:j:q:::::M:::.::6::o::::::e:#:E::::T:::::O:u:8::s:x::Y:::*::a:::::a:S:::T
242::.:1::::5:g:5:::::::J::Q::i:p::7:v::R::H:::::v:::2:::V::::O::I::::::k:4:::^:::::0:R:m:::Q::V:::::w:H
243:a:t:::x:::~:::u:::::Q::_::::::B:Z:7::::S:k:R::::x:E::?:::::w:.::K::::0:k::::w:~::::t::8::8::K::::::W:::w:::S
244:G::J:::K:G::::h:^::::|:F:::_:::::5:g:::a:::6:E:::::::!:.::4:::::::::L:}:D::p:N:::::::::l::$:::::::0:::::A
245::Y:2:::::::y:U:~:::::::::Y:W::=:::8:::#:::D::U:::}:::{:::8:{::s::=::::::!:::q:::::Z:,::P:0:::::::!
246:S::3:::}:::!:v::::?::::::::-::a::l:Y:M::::::::8:q:Y::s:::J::N:a:,::::::S::::?::*::::H:D:s::::::X
247:-::::::4:::{:l::6:::W::G::::::::::v:3:::y::p::l:::::Z::P:::::::::::::::::n:::D:i:U::::::h:::h::$
248:Q::9::d:::1::@:~:0:l:e::K:::::::::::I:F::::::Q:M::Y:g:H::h::j::K::::::::h:g:{:V:W:X::::::6:::::=:::::m:h:*
249::M::-:::7::j::t::}:8:::w:N::`:%:A:!:t:l:::::T::::::::d:M::Y::x:1::::::::^:~::C::::::p:a:::::Y::J:::::O
250:::b:::::Q:::0:S::X::^:::s:::::V:T:::x:n::P::3:!:::I:::::::::j:6:::|:!:::::F::::A:C:::X::n:H::H:L:::!:p
251:V:::::::::::::::,:r::1::_:::::::::::::h::P:::::5:=:R::J:0:Y::6::b:V::2::::::::::-::::1:::9
252::::::::::z::?::Z:::::c:::::::::,:g:w:V:r:::V:?:::.:::::::Z::::::$:w:@::I:::~:v::::::o::@::::k
253:::o::I:::K::::a::::::::::z::k:+:::::::b:::::::::g:::::::y:::-:::7::::5::::f:::`::::::::l:g
254:::0:b:::::=:::E:9:J::p:::M:::::c:::::::::::$::r:::::::@::s:@:%:::6:::4:::d:.:!:g:::.::::::i
255::::::::::::::::::::x::::::Y::::::9:::^::Q::I:Z:9:::_::6:-::h::Q::Q::::u:::s::::M::::M::b:::::V
EOF

my %unmangling_table;

for my $line ( split /\n/, $unmangle_data ) {
	my ($num, $rest) = split(/:/, $line, 2);
	my @fields = split(':', $rest);
	$unmangling_table{$num} = [ @fields ];
}

my $attachment_nobody = q{<br>
<i>[Attachment content not displayed.]</i><br><br>
</td></tr>
</table>};

# By default works in verbose mode unless VERBOSE=0 via environment variable for cron job.
my $VERBOSE = 1;
$VERBOSE = $ENV{'VERBOSE'} if $ENV{'VERBOSE'};

my $SAVEALL = 0; # Force download every file even if the file exists locally.
my $REFRESH = 1; # Download only those messages which dont already exist.

my $GETADULT = 1; # Allow adult groups to be downloaded.

my $COOKIE_SAVE = 1; # Save cookies before finishing - wont if aborted.
my $COOKIE_LOAD = 1; # Load cookies if saved from previous session.

$| = 1 if ($VERBOSE); # Want to see the messages immediately if I am in verbose mode

my $username = ''; # Better here than the commandline.
my $password = $ENV{'GY_PASSWD'};
$password = '' unless $password; # Better here than the commandline.
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst

my ($user_group, $bmsg, $emsg) = @ARGV;

die "Please specify a group to process\n" unless $user_group;

my $begin_msgid;
my $end_msgid;

if (defined $bmsg) {
	if ($bmsg =~ /^(\d+)$/) {
		$begin_msgid = $1;
	} else {
		die "Begin message id should be integer\n";
	}
}

if (defined $emsg) {
	if ($emsg =~ /^(\d+)$/) {
		$end_msgid = $1;
	} else {
		die "End message id should be integer\n";
	}
}

die "End message id : $end_msgid should be greater than begin message id : $begin_msgid\n" if ($end_msgid and $end_msgid < $begin_msgid);

my ($group) = $user_group =~ /^([\w_\-]+)$/;

unless (-d $group or mkdir $group) {
	print STDERR "$! : $group\n" if $VERBOSE;
}

my $Cookie_file = "$group/yahoogroups.cookies";

my $ua = LWP::UserAgent->new;
$ua->proxy('http', $HTTP_PROXY_URL) if $HTTP_PROXY_URL;
$ua->agent($USER_AGENT);
$ua->timeout($TIMEOUT*60);
print "Setting timeout to : " . $ua->timeout() . "\n" if $VERBOSE;
my $cookie_jar = HTTP::Cookies->new( 'file' => $Cookie_file );
$ua->cookie_jar($cookie_jar);
my $request;
my $response;
my $url;
my $content;
if ($COOKIE_LOAD and -f $Cookie_file) {
	$cookie_jar->load();
}

$request = GET "http://groups.yahoo.com/group/$group/messages/1";

$request = GET "http://groups.yahoo.com/group/$group/messages/1";
$response = $ua->simple_request($request);
if ($response->is_error) {
	print STDERR "[http://groups.yahoo.com/group/$group/messages/1] " . $response->as_string . "\n" if $VERBOSE;
	exit;
}

while ( $response->is_redirect ) {
	$cookie_jar->extract_cookies($response);
	$url = GetRedirectUrl($response);
	$request = GET $url;
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
		exit;
	}
}
$cookie_jar->extract_cookies($response);

$content = $response->content;

my $login_rand;
my $u;
my $challenge;

if ($content =~ /Sign in with your ID and password to continue/ or $content =~ /Verify your Yahoo! password to continue/ or $content =~ /sign in<\/a> now/) {
	($login_rand) = $content =~ /<form method=post action="https:\/\/login.yahoo.com\/config\/login\?(.+?)"/s;
	($u) = $content =~ /<input type=hidden name=".u" value="(.+?)" >/s;
	($challenge) = $content =~ /<input type=hidden name=".challenge" value="(.+?)" >/s;

	unless ($username) {
		my ($slogin) = $content =~ /<input type=hidden name=".slogin" value="(.+?)" >/;
		$username = $slogin if $slogin;
	}

	unless ($username) {
		print "Enter username : ";
		$username = <STDIN>;
		chomp $username;
	}

	unless ($password) {
		use Term::ReadKey;
		ReadMode('noecho');
		print "Enter password : ";
		$password = ReadLine(0);
		ReadMode('restore');
		chomp $password;
		print "\n";
	}

	$request = POST 'http://login.yahoo.com/config/login',
		[
		 '.tries' => '1',
		 '.src'   => 'ygrp',
		 '.md5'   => '',
		 '.hash'  => '',
		 '.js'    => '',
		 '.last'  => '',
		 'promo'  => '',
		 '.intl'  => 'us',
		 '.bypass' => '',
		 '.partner' => '',
		 '.u'     => $u,
		 '.v'     => 0,
		 '.challenge' => $challenge,
		 '.yplus' => '',
		 '.emailCode' => '',
		 'pkg'    => '',
		 'stepid' => '',
		 '.ev'    => '',
		 'hasMsgr' => 0,
		 '.chkP'  => 'Y',
		 '.done'  => "http://groups.yahoo.com/group/$group/messages/1",
		 'login'  => $username,
		 'passwd' => $password,
		 '.persistent' => 'y',
		 '.save'  => 'Sign In'
		];
	
	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[http://login.yahoo.com/config/login] " . $response->as_string . "\n" if $VERBOSE;
		exit;
	}
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
	}

	$content = $response->content;

	die "Couldn't log in $username\n" if ( !$response->is_success );

	die "Wrong password entered for $username\n" if ( $content =~ /Invalid Password/ );

	die "Yahoo user $username does not exist\n" if ( $content =~ /ID does not exist/ );

	print "Successfully logged in as $username.\n" if $VERBOSE; 
}


if (($content =~ /You've reached an Age-Restricted Area of Yahoo! Groups/) or ($content =~ /you have reached an age-restricted area of Yahoo! Groups/)) {
	if ($GETADULT) {
		$request = POST 'http://groups.yahoo.com/adultconf',
			[
			 'ref' => '',
			 'dest'  => "/group/$group/messages/1",
			 'accept' => 'I Accept'
			];
	
		$request->content_type('application/x-www-form-urlencoded');
		$request->header('Accept' => '*/*');
		$request->header('Allowed' => 'GET HEAD PUT');
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[http://groups.yahoo.com/adultconf] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
	
		while ( $response->is_redirect ) {
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
		}

		$content = $response->content;
	
		print "Confirmed as a adult\n" if $VERBOSE;
	} else {
		print STDERR "This is a adult group exiting\n" if $VERBOSE;
		exit;
	}
}

eval {
	my $b;
	my $e;
	unless ($end_msgid) {
		$content = $response->content;
		($b, $e) = $content =~ /(\d+)-\d+ of (\d+) /;
		die "Couldn't get message count" unless $e;
	}
	$begin_msgid = $b unless $begin_msgid;
	$end_msgid = $e unless $end_msgid;
	die "End message id :$end_msgid should be greater than begin message id : $begin_msgid\n" if ($end_msgid < $begin_msgid);

	print "Processing messages between $begin_msgid and $end_msgid\n" if $VERBOSE;

	foreach my $messageid ($begin_msgid..$end_msgid) {
		next if $REFRESH and -f "$group/$messageid";
		print "$messageid: " if $VERBOSE;

		$url = "http://groups.yahoo.com/group/$group/message/$messageid?source=1\&unwrap=1";
		$request = GET $url;
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[http://groups.yahoo.com/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
		while ( $response->is_redirect ) {
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
		}
		$content = $response->content;
		# If the page comes up with just a advertizement without the message.
		if ($content =~ /Continue to message/s) {
			$url = "http://groups.yahoo.com/group/$group/message/$messageid?source=1\&unwrap=1";
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[http://groups.yahoo.com/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			$content = $response->content;
		}

		# If the page has been purged from the system
		if ($content =~ /Message $messageid does not exist in $group/s) {
			print "\tmessage purged from the system\n" if $VERBOSE;
			open (MFD, "> $group/$messageid");
			close MFD;
			next;
		}

		my ($email_content) = $content =~ /<!-- start content include -->\s(.+?)\s<!-- end content include -->/s;

		my ($email_header, $rest) = $email_content =~ /<table.+?<tt>(.+?)<\/tt>(.+)/s;
		if ($rest eq $attachment_nobody) {
			print "... body contains attachment with no body\n";
			open (MFD, "> $group/$messageid");
			close MFD;
			next;
		}
		my ($email_body) = $rest =~ /<tt>(.+?)<\/td>/s;

		$email_header =~ s/<br>//gi;
		$email_header =~ s/<a.+?protectID=(.+?)".+?<\/a>/&extract_email($1)/esg;
		$email_header =~ s/<a href=".+?>(.+?)<\/a>/$1/g; # Yahoo hyperlinks every URL which is not already a hyperlink.
		$email_header =~ s/<.+?>//g;
		$email_header = HTML::Entities::decode($email_header);
		$email_body =~ s/<br>//gi;
		$email_body =~ s/<a.+?protectID=(.+?)".+?<\/a>/&extract_email($1)/esg;
		$email_body =~ s/<a href=".+?>(.+?)<\/a>/$1/g; # Yahoo hyperlinks every URL which is not already a hyperlink.
		$email_body =~ s/<.+?>//g;
		$email_body = HTML::Entities::decode($email_body);
		open (MFD, "> $group/$messageid");
		print MFD $email_header;
		print MFD "\n";
		print MFD $email_body;
		close MFD;
		print "\n" if $VERBOSE;
	}

	$cookie_jar->save if $COOKIE_SAVE;
};

if ($@) {
	$cookie_jar->save if $COOKIE_SAVE;
	die $@;
}

sub GetRedirectUrl($) {
	my ($response) = @_;
	my $url = $response->header('Location') || return undef;

	# the Location URL is sometimes non-absolute which is not allowed, fix it
	local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
	my $base = $response->base;
	$url = $HTTP::URI_CLASS->new($url, $base)->abs($base);

	return $url;
}

sub extract_email {
	my ($crypt_email) = @_;
	my $email = "";
	my @nums = unpack("A3" x (length($crypt_email)/3), $crypt_email);

	for ( my $x = 0; $x <= $#nums; $x++ ) {
		if ( defined $unmangling_table{$nums[$x]}[$x] and $unmangling_table{$nums[$x]}[$x] ne "" ) {
			$email .= $unmangling_table{$nums[$x]}[$x];
		} else {
			print STDERR "\nUnknown unmangling entry: (" . $nums[$x] . ", " . $x . ")\n";
			$email .= "*";
		}
	}

	return $email;
}
