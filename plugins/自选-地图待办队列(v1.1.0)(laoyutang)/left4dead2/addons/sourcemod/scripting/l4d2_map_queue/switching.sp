// Runtime lifecycle and fallback handlers for l4d2_map_queue.sp.

void ObserveFinaleEvent(const char[] source)
{
	if (g_MapChanging || !IsSupportedMode() || !L4D_IsMissionFinalMap())
		return;
	if (!g_FinaleSeen)
		LogMessage("[MapQueue] finale signal: source=%s map_serial=%d op=%d", source, g_MapSerial, g_OperationSerial);
	g_FinaleSeen = true;
	TryCompleteCampaign();
}

Action Message_Stats(UserMsg id, BfRead message, const int[] players, int count, bool reliable, bool init)
{
	if (!g_MapChanging && IsSupportedMode() && L4D_IsMissionFinalMap())
	{
		if (!g_StatsSeen)
			LogMessage("[MapQueue] stats observed: map_serial=%d op=%d", g_MapSerial, g_OperationSerial);
		g_StatsSeen = true;
	}
	return Plugin_Continue;
}

void Message_StatsPost(UserMsg id, bool sent)
{
	if (sent && g_StatsSeen && !g_MapChanging)
	{
		g_StatsSent = true;
		// Paused queues release map_changer. Its post hook may unload the map
		// before our deferred frame; persist this completion quietly now.
		// There is no target to prepare, SDK call, or outbound usermessage.
		if (g_State == QueueState_Paused)
		{
			TryCompleteCampaign(true, true, true);
			return;
		}
		QueueCompletionFrame();
	}
}

void QueueCompletionFrame()
{
	DataPack pack = new DataPack();
	pack.WriteCell(g_MapSerial);
	pack.WriteCell(g_OperationSerial);
	RequestFrame(Frame_CompleteCampaign, pack);
}

void Frame_CompleteCampaign(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int mapSerial = pack.ReadCell();
	int operationSerial = pack.ReadCell();
	delete pack;
	if (mapSerial != g_MapSerial || operationSerial != g_OperationSerial || g_MapChanging || g_ShuttingDown)
		return;
	// Existing event timers always win. Stats can only fill a missing trigger.
	if (!g_FinaleHandled && (g_FinaleSeen || g_StatsSent))
		TryCompleteCampaign(!g_FinaleSeen);
	else if (g_FinaleHandled && g_State == QueueState_Delay && g_hAdvanceTimer == null)
		AdvanceQueue(true);
}

Action Message_Lobby(UserMsg id, BfRead message, const int[] players, int count, bool reliable, bool init)
{
	if (!g_Initialized || !g_cvEnable.BoolValue || g_MapChanging || g_ShuttingDown || !IsAutomationActive()
		|| !IsSupportedMode() || !L4D_IsMissionFinalMap() || (!g_FinaleSeen && !g_StatsSeen))
		return Plugin_Continue;
	// Preserve the complete bitbuffer byte payload, without assuming a reason
	// string format. Oversized messages pass through rather than being damaged.
	int length = BfGetNumBytesLeft(message);
	if (length < 0 || length > LOBBY_PAYLOAD_LENGTH || g_LobbyNotices.Length >= MAX_LOBBY_NOTICES)
	{
		LogError("[MapQueue] lobby fallback declined: payload=%d buffered=%d", length, g_LobbyNotices.Length);
		return Plugin_Continue;
	}
	LobbyNotice notice;
	notice.length = length;
	notice.mapSerial = g_MapSerial;
	notice.flags = (reliable ? USERMSG_RELIABLE : 0) | (init ? USERMSG_INITMSG : 0);
	for (int i = 0; i < count && notice.count < sizeof(notice.serials); i++)
	{
		int client = players[i];
		if (client > 0 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client))
			notice.serials[notice.count++] = GetClientSerial(client);
	}
	if (notice.count == 0)
		return Plugin_Continue;
	for (int i = 0; i < length; i++)
		notice.bytes[i] = BfReadByte(message);

	// Validate against the existing catalog here; mission SDK calls and all
	// notifications/level changes are deferred until the message hook exits.
	if (!g_FinaleHandled && !g_SwitchPending && !TryCompleteCampaign(true, true, true))
		return Plugin_Continue;
	if (g_State == QueueState_Delay && !AdvanceQueue(true, true))
		return Plugin_Continue;
	if (g_State != QueueState_Running || !g_HasActive || !g_SwitchPending)
		return Plugin_Continue;
	MapEntry resolved;
	char error[256];
	if (!ResolveMapEntry(g_Active.map, resolved, error, sizeof(error)))
	{
		LogError("[MapQueue] lobby fallback invalid target: %s", error);
		return Plugin_Continue;
	}
	g_LobbyNotices.PushArray(notice);
	LogMessage("[MapQueue] lobby held: target=%s attempt=%d map_serial=%d op=%d", g_ExpectedMap, g_SwitchAttempts, g_MapSerial, g_OperationSerial);
	return Plugin_Handled;
}

void QueueLobbyRestore()
{
	if (g_LobbyNotices == null || g_LobbyNotices.Length == 0 || g_LobbyRestoreQueued || g_MapChanging)
		return;
	g_LobbyRestoreQueued = true;
	RequestFrame(Frame_RestoreLobby);
}

void Frame_RestoreLobby(any data)
{
	g_LobbyRestoreQueued = false;
	// A replacement run/skip can take over the same held notice before this
	// frame executes. Do not send players to the lobby during its new request.
	if (!g_SwitchPending)
		RestoreLobbyNotices();
}

void RestoreLobbyNotices()
{
	if (g_LobbyNotices == null)
		return;
	LobbyNotice notice;
	int players[MAXPLAYERS + 1];
	for (int n = 0; n < g_LobbyNotices.Length; n++)
	{
		g_LobbyNotices.GetArray(n, notice);
		if (notice.mapSerial != g_MapSerial || g_MapChanging)
			continue;
		int count;
		for (int i = 0; i < notice.count; i++)
		{
			int client = GetClientFromSerial(notice.serials[i]);
			if (client > 0 && IsClientConnected(client) && !IsFakeClient(client))
				players[count++] = client;
		}
		if (count == 0)
			continue;
		Handle output = StartMessageEx(g_umLobby, players, count, notice.flags | USERMSG_BLOCKHOOKS);
		if (output != null)
		{
			for (int i = 0; i < notice.length; i++)
				BfWriteByte(output, notice.bytes[i]);
			EndMessage();
			LogMessage("[MapQueue] held lobby restored: recipients=%d bytes=%d map_serial=%d", count, notice.length, g_MapSerial);
		}
	}
	DiscardLobbyNotices();
}

void DiscardLobbyNotices()
{
	if (g_LobbyNotices != null)
		g_LobbyNotices.Clear();
	g_LobbyRestoreQueued = false;
}

Action Timer_ConfirmSwitch(Handle timer, any data)
{
	if (timer != g_hConfirmTimer || data != g_OperationSerial)
		return Plugin_Stop;
	if (g_SwitchDeadline != 0 && GetTime() >= g_SwitchDeadline)
	{
		// The current callback closes its own timer; a retry creates a new one.
		g_hConfirmTimer = null;
		CheckSwitchRequest();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void CheckSwitchRequest()
{
	if (g_ShuttingDown || g_MapChanging || !g_SwitchPending || g_SwitchAttempts == 0
		|| g_SwitchDeadline == 0 || GetTime() < g_SwitchDeadline)
		return;
	if (g_State != QueueState_Running || !g_HasActive || !g_cvEnable.BoolValue)
	{
		CancelAllTimers(true);
		return;
	}
	if (g_SwitchAttempts < 2)
	{
		LogMessage("[MapQueue] switch not started; trying fallback: target=%s map_serial=%d op=%d", g_ExpectedMap, g_MapSerial, g_OperationSerial);
		SwitchToActiveMap(g_SwitchAllowEmpty, true);
	}
	else
		StopAndRequeueActive("切图请求未生效，队列已停止；尚未进入的项目已放回队首。");
}

void ConfirmLoadedMap()
{
	if (g_SwitchPending)
	{
		char actual[MAP_NAME_LENGTH];
		GetCurrentMap(actual, sizeof(actual));
		if (StrEqual(actual, g_ExpectedMap, false))
			LogMessage("[MapQueue] target loaded: target=%s attempt=%d map_serial=%d op=%d", actual, g_SwitchAttempts, g_MapSerial, g_OperationSerial);
		else
			LogMessage("[MapQueue] external map change cancelled confirmation: expected=%s actual=%s; keeping existing queue rules", g_ExpectedMap, actual);
	}
	CancelAllTimers();
	DiscardLobbyNotices();
}

int CountConnectedHumans()
{
	int count;
	for (int client = 1; client <= MaxClients; client++)
		if (IsClientConnected(client) && !IsFakeClient(client))
			count++;
	return count;
}

bool IsTrulyEmpty()
{
	if (CountConnectedHumans() > 0 || g_MapChanging)
		return false;
	int now = GetTime();
	if (g_ReconnectDeadline > now)
		return false;
	if (g_SwitchPending && g_SwitchAttempts > 0 && g_SwitchDeadline > now)
		return false;
	return true;
}

void BeginReconnectGrace()
{
	delete g_hReconnectTimer;
	g_ReconnectDeadline = GetTime() + RoundToCeil(g_cvReconnectGrace.FloatValue);
	g_hReconnectTimer = CreateTimer(1.0, Timer_ReconnectGrace, g_MapSerial, TIMER_REPEAT);
	if (IsAutomationActive())
		LogMessage("[MapQueue] reconnect grace started: seconds=%.1f map_serial=%d connected=%d ingame=%d", g_cvReconnectGrace.FloatValue, g_MapSerial, CountConnectedHumans(), CountHumanPlayers());
}

Action Timer_ReconnectGrace(Handle timer, any data)
{
	if (timer != g_hReconnectTimer || data != g_MapSerial)
		return Plugin_Stop;
	g_hReconnectTimer = null;
	CheckEmptyServer();
	if (g_ReconnectDeadline == 0 || g_ShuttingDown || g_MapChanging)
		return Plugin_Stop;
	g_hReconnectTimer = timer;
	return Plugin_Continue;
}

void CheckEmptyServer()
{
	if (g_ShuttingDown || g_MapChanging || !g_Initialized)
		return;
	if (g_ReconnectDeadline != 0 && GetTime() >= g_ReconnectDeadline)
	{
		g_ReconnectDeadline = 0;
		delete g_hReconnectTimer;
		LogMessage("[MapQueue] reconnect grace expired: map_serial=%d connected=%d ingame=%d", g_MapSerial, CountConnectedHumans(), CountHumanPlayers());
	}
	if (IsAutomationActive() && IsTrulyEmpty())
		StopForEmptyServer();
}

void LogQueueStop(const char[] reason)
{
	char map[MAP_NAME_LENGTH];
	char state[16];
	GetCurrentMap(map, sizeof(map));
	GetQueueStateName(g_State, state, sizeof(state));
	LogMessage("[MapQueue] stop: reason=%s state=%s active=%s pending=%d map=%s map_serial=%d op=%d connected=%d ingame=%d",
		reason, state, g_HasActive ? g_Active.map : "-", g_Queue.Length, map, g_MapSerial, g_OperationSerial, CountConnectedHumans(), CountHumanPlayers());
}

void ResetFinaleContext()
{
	g_FinaleSeen = false;
	g_StatsSeen = false;
	g_StatsSent = false;
	g_FinaleHandled = false;
	g_IgnoreFinaleUntilMapStart = false;
}

Action Event_QueueRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_RoundEnded = true;
	return Plugin_Continue;
}

void ResetQueueRoundContext(bool preEntity = false)
{
	if (g_FirstRound || (!preEntity && !g_RoundEnded) || g_MapChanging)
		return;
	g_RoundEnded = false;
	if (g_State == QueueState_Delay || g_SwitchPending)
	{
		if (g_SwitchPending)
			RequeueActiveInMemory();
		g_State = g_Queue.Length > 0 ? QueueState_Armed : QueueState_Stopped;
		CancelAllTimers();
		DiscardLobbyNotices();
		if (!SaveQueueState())
			StopAndRequeueActive("原地重开后的队列保存失败，队列已停止。");
	}
	else
		g_OperationSerial++;
	ResetFinaleContext();
	SyncMapChangerControl();
}

Action Event_QueueRoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	ResetQueueRoundContext(true);
	return Plugin_Continue;
}

Action Event_QueueRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetQueueRoundContext();
	g_FirstRound = false;
	g_RoundEnded = false;
	return Plugin_Continue;
}

bool IsSafeCommandMap(const char[] map)
{
	if (!map[0])
		return false;
	for (int i = 0; map[i]; i++)
	{
		int c = map[i];
		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.'))
			return false;
	}
	return true;
}
