/++
+ This module deals with creating responses to packets received from client
+ and providing information for 
+/
module authserver.packet_handler;

import std.conv;
import util.typecons;

import wowdefs.wow_versions;

import authprotocol.defines;
import authprotocol.packet_data;

import util.crypto.srp6;
import authserver.database.dao;

auto handleRealmList(ProtocolVersion VER, PACKET, REALM_DAO)(in PACKET packet, REALM_DAO realmDao)
{
    auto response = PacketResponse!(PACKET)();
    auto result = realmDao.getAll();
    response.realms = new authprotocol.packet_data.RealmInfo!(VER)[result.length];
    size_t i = 0;
    foreach (realm ; result)
    {   
        auto realmData = authprotocol.packet_data.RealmInfo!(VER)(cast(RealmFlags)realm.flag, realm.name.to!(char[]),
                                                                  (realm.address.to!string ~ ":" ~realm.port.to!string).to!(char[]), realm.population, 0, realm.timezone, realm.icon);
        static if (VER == ProtocolVersion.POST_BC)
        {
            auto pi = getPatchInfo(cast(WowVersion)realm.gamebuild);
            realmData.build = BuildInfo(pi.major, pi.minor, pi.bugfix, cast(WowVersion)realm.gamebuild);
            realmData.unk = 0x2C;
        }
        else
            realmData.unk = 0x0;
        response.realms[i++] = realmData;
    }

    if (VER == ProtocolVersion.POST_BC)
    {
        response.unk1 = 0x10;
        response.unk2 = 0x0;
    }
    else
    {
        response.unk1 = 0x0;
        response.unk2 = 0x2;
    }
    return response;
}

Tuple!(PacketResponse!(PACKET), "packet", bool, "end")
handleLogonProof(ProtocolVersion VER, PACKET, CHALLENGE)(in PACKET packet, in CHALLENGE challenge, in AuthDetailedDto authInfo)
{
    import util.crypto.big_num;
    import std.system;
    auto response = PacketResponse!(PACKET)();

    auto proof = challenge.challenge(cast(ubyte[])authInfo.username, BigNumber(authInfo.s).toByteArray(Endian.littleEndian), BigNumber(authInfo.v).toByteArray(Endian.littleEndian), packet.A);

    auto authResult = proof.authenticate(packet.M1);
    if (authResult is null)
    {
        response.error = AuthResult.WOW_FAIL_UNKNOWN_ACCOUNT;
        response.unkAccError = typeof(response).UnknownAccError();
        return typeof(return)(response, true);
    }

    response.error = AuthResult.WOW_SUCCESS;
    auto respProof = typeof(response).Proof();
    respProof.M2 []= (*authResult).M2[];
    static if (VER == ProtocolVersion.POST_BC)
    {
        respProof.flags = AccountFlags.PRO_PASS;
    }
    response.proof = respProof;
    return typeof(return)(response, false);
}

Tuple!(PacketResponse!(PACKET), "packet", bool, "end", ServerChallenge!(SRPTYPE), "challenge", Nullable!AuthDetailedDto, "authInfo", ProtocolVersion, "version_")
handleLogonChallenge(PACKET, SRPTYPE, AUTH_DAO)(in PACKET packet, in SRPTYPE srp, AUTH_DAO authDao, in string connectionIp)
{
    import util.crypto.big_num;

    auto protocolVersion = packet.build.major >= MajorWowVersion.TBC ? ProtocolVersion.POST_BC : ProtocolVersion.PRE_BC;

    auto response = PacketResponse!(PACKET)();

    auto challenge = new ServerChallenge!(SRPTYPE)(util.crypto.big_num.random(19*8).toByteArray(Endian.littleEndian)[],srp);

    auto authInfo = authDao.getDetailed(packet.accountName);

    response.result = checkLoginAttempt(authInfo, connectionIp, authDao);
    auto secInf = typeof(response).SecurityInfo();
    auto bbytes = challenge.calculateB(BigNumber(authInfo.v).toByteArray(Endian.littleEndian));
    bbytes.length = 32;
    secInf.B []= bbytes[];
    secInf.g = srp.gbytes();
    secInf.N = srp.Nbytes();
    secInf.s []= BigNumber(authInfo.s).toByteArray(Endian.littleEndian)[];
    secInf.unkRand []= util.crypto.big_num.random(16*8).toByteArray(Endian.littleEndian)[];

    response.info = secInf;
    return typeof(return)(response, false, challenge, authInfo, protocolVersion);
}

AuthResult checkLoginAttempt(AUTH_DAO)(in Nullable!AuthDetailedDto authInfo, string connectionIp, AUTH_DAO authDao)
{
    // check for ip ban
    auto banInfo = authDao.getIpBanned(connectionIp);
    if (!banInfo.isNull())
    {
        return AuthResult.WOW_FAIL_BANNED;
    }
    // check account existence
    if (authInfo.isNull())
    {
        return AuthResult.WOW_FAIL_UNKNOWN_ACCOUNT;
    }
    // check account lock to ip
    if (authInfo.locked && authInfo.lastIp != connectionIp)
    {
        return AuthResult.WOW_FAIL_LOCKED_ENFORCED;
    }
    // check account lock to country
    if (authInfo.country != "" && authInfo.country != "00" && authDao.getCountry(connectionIp) != authInfo.country)
    {
        return AuthResult.WOW_FAIL_UNLOCKABLE_LOCK;
    }
    // check account ban and suspension
    auto accountBanInfo = authDao.getAccountBanned(authInfo.id);
    if (!accountBanInfo.isNull())
    {
        if (accountBanInfo.suspended())
            return AuthResult.WOW_FAIL_SUSPENDED;
        else
            return AuthResult.WOW_FAIL_BANNED;
    }
    return AuthResult.WOW_SUCCESS;
}

unittest {
    import dmocks.mocks;
    import authserver.database.dao;

    auto mocker = new Mocker;

    auto authDao = mocker.mockFinalPassTo!(AuthDao)(null);

    string ip = "127.0.0.1";
    auto authInfo = nullable!AuthDetailedDto("test");
    mocker.allowUnexpectedCalls(true);
    mocker.expect(authDao.getIpBanned(ip)).returns(nullable!IpBannedDto(ip, 0, 0, "", ""));
    mocker.expect(authDao.getCountry(ip)).returns(nullable!string("UK"));
    mocker.replay;
    assert(checkLoginAttempt(authInfo, ip, authDao) == AuthResult.WOW_FAIL_BANNED);
}

unittest {
    import dmocks.mocks;
    import authserver.database.dao;
    import util.typecons;

    auto mocker = new Mocker;

    auto authDao = mocker.mockFinalPassTo!(AuthDao)(null);

    string name = "test";
    string ip = "127.0.0.1";
    mocker.allowUnexpectedCalls(true);
    mocker.expect(authDao.getCountry(ip)).returns(nullable!string("UK"));
    auto authInfo = nullable!AuthDetailedDto(name, "", 1, true, "UK", "127.0.0.2", 0, "", "");

    mocker.replay;
    assert(checkLoginAttempt(authInfo, ip, authDao) == AuthResult.WOW_FAIL_LOCKED_ENFORCED);
}

unittest {
    import dmocks.mocks;
    import authserver.database.dao;
    import util.typecons;

    auto mocker = new Mocker;

    auto authDao = mocker.mockFinalPassTo!(AuthDao)(null);

    string ip = "127.0.0.1";
    auto authInfo = nullable!AuthDetailedDto("test");
    mocker.allowUnexpectedCalls(true);
    mocker.expect(authDao.getIpBanned(ip)).ignoreArgs.returns(nullable!IpBannedDto(ip, 0, 1, "", ""));
    mocker.expect(authDao.getCountry(ip)).returns(nullable!string("UK"));
    mocker.replay;
    assert(checkLoginAttempt(authInfo, ip, authDao) == AuthResult.WOW_FAIL_BANNED);
}

unittest {
    import dmocks.mocks;
    import authserver.database.dao;
    import util.typecons;

    auto mocker = new Mocker;

    auto authDao = mocker.mockFinalPassTo!(AuthDao)(null);

    string ip = "127.0.0.1";
    long accId = 1;
    string name = "test";
    auto authInfo = nullable!AuthDetailedDto(name, "", accId, false, "US", "127.0.0.2", 0, "", "");
    mocker.allowUnexpectedCalls(true);
    mocker.expect(authDao.getCountry(ip)).returns(nullable!string("UK"));
    mocker.replay;
    assert(checkLoginAttempt(authInfo, ip, authDao) == AuthResult.WOW_FAIL_UNLOCKABLE_LOCK);
}

unittest {
    import dmocks.mocks;
    import authserver.database.dao;
    import util.typecons;

    auto mocker = new Mocker;

    auto authDao = mocker.mockFinalPassTo!(AuthDao)(null);

    string ip = "127.0.0.1";
    long accId = 1;
    string name = "test";
    auto authInfo = nullable!AuthDetailedDto(name, "", accId, true, "UK", "127.0.0.1", 0, "", "");
    mocker.allowUnexpectedCalls(true);
    mocker.expect(authDao.getCountry(ip)).returns(nullable!string("UK"));
    mocker.replay;
    assert(checkLoginAttempt(authInfo, ip, authDao) == AuthResult.WOW_SUCCESS);
}