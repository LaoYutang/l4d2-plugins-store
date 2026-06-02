#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0.0"
#define CFG_ROOT "cfg"
#define TEMP_SUFFIX ".tmp"
#define BACKUP_SUFFIX ".bak"
#define UTF8_MAX_BYTES 4

#define FIX_FAILED -1
#define FIX_UNCHANGED 0
#define FIX_CHANGED 1

public Plugin myinfo =
{
	name = "Chinese Comment Cfg Fixer",
	author = "laoyutang",
	description = "Fixes Chinese comment command leakage in cfg files.",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_fix_chinese_cfg", Command_FixChineseCfg, ADMFLAG_ROOT, "Scan and fix Chinese comment cfg leakage.");
	AddCommandListener(Command_ExecListener, "exec");
}

public Action Command_FixChineseCfg(int client, int args)
{
	int scanned;
	int changed;
	int failed;
	FixAllCfgFiles(scanned, changed, failed);

	ReplyToCommand(client, "[SM] Chinese cfg fixer finished: scanned=%d changed=%d failed=%d", scanned, changed, failed);
	return Plugin_Handled;
}

public Action Command_ExecListener(int client, const char[] command, int argc)
{
	if (argc < 1)
	{
		return Plugin_Continue;
	}

	char execArg[PLATFORM_MAX_PATH];
	GetCmdArg(1, execArg, sizeof(execArg));

	char cfgPath[PLATFORM_MAX_PATH];
	if (!BuildExecCfgPath(execArg, cfgPath, sizeof(cfgPath)))
	{
		return Plugin_Continue;
	}

	if (!FileExists(cfgPath))
	{
		return Plugin_Continue;
	}

	int result = FixCfgFile(cfgPath);
	if (result == FIX_CHANGED)
	{
		LogMessage("Fixed cfg before exec: %s", cfgPath);
	}

	return Plugin_Continue;
}

bool BuildExecCfgPath(const char[] execArg, char[] cfgPath, int maxLength)
{
	char path[PLATFORM_MAX_PATH];
	strcopy(path, sizeof(path), execArg);
	NormalizeSlashes(path);

	if (path[0] == '\0'
		|| path[0] == '/'
		|| StrContains(path, ":") != -1
		|| StrContains(path, "..") != -1
		|| StrContains(path, "file://", false) == 0)
	{
		return false;
	}

	if (!PathHasCfgExtension(path))
	{
		if (strlen(path) + 5 > sizeof(path))
		{
			return false;
		}

		StrCat(path, sizeof(path), ".cfg");
	}

	if (StrContains(path, "cfg/", false) == 0)
	{
		return strcopy(cfgPath, maxLength, path) < maxLength;
	}

	if (strlen(CFG_ROOT) + 1 + strlen(path) + 1 > maxLength)
	{
		return false;
	}

	FormatEx(cfgPath, maxLength, "%s/%s", CFG_ROOT, path);
	return true;
}

void NormalizeSlashes(char[] path)
{
	int length = strlen(path);
	for (int i = 0; i < length; i++)
	{
		if (path[i] == '\\')
		{
			path[i] = '/';
		}
	}
}

bool PathHasCfgExtension(const char[] path)
{
	int length = strlen(path);
	return length >= 4 && StrEqual(path[length - 4], ".cfg", false);
}

void FixAllCfgFiles(int &scanned, int &changed, int &failed)
{
	scanned = 0;
	changed = 0;
	failed = 0;

	if (!DirExists(CFG_ROOT))
	{
		LogError("Cfg root does not exist: %s", CFG_ROOT);
		failed++;
		return;
	}

	ProcessCfgDirectory(CFG_ROOT, scanned, changed, failed);
}

void ProcessCfgDirectory(const char[] directory, int &scanned, int &changed, int &failed)
{
	DirectoryListing listing = OpenDirectory(directory);
	if (listing == null)
	{
		LogError("Failed to open cfg directory: %s", directory);
		failed++;
		return;
	}

	char entry[PLATFORM_MAX_PATH];
	char path[PLATFORM_MAX_PATH];
	FileType type;

	while (listing.GetNext(entry, sizeof(entry), type))
	{
		if (StrEqual(entry, ".") || StrEqual(entry, ".."))
		{
			continue;
		}

		if (!JoinPath(directory, entry, path, sizeof(path)))
		{
			LogError("Cfg path is too long: %s/%s", directory, entry);
			failed++;
			continue;
		}

		if (type == FileType_Directory)
		{
			ProcessCfgDirectory(path, scanned, changed, failed);
			continue;
		}

		if (type != FileType_File || !IsCfgFile(entry))
		{
			continue;
		}

		scanned++;

		int result = FixCfgFile(path);
		if (result == FIX_CHANGED)
		{
			changed++;
		}
		else if (result == FIX_FAILED)
		{
			failed++;
		}
	}

	delete listing;
}

bool JoinPath(const char[] parent, const char[] child, char[] output, int maxLength)
{
	int needed = strlen(parent) + 1 + strlen(child) + 1;
	if (needed > maxLength)
	{
		return false;
	}

	FormatEx(output, maxLength, "%s/%s", parent, child);
	return true;
}

bool IsCfgFile(const char[] name)
{
	return PathHasCfgExtension(name);
}

int FixCfgFile(const char[] path)
{
	int fileSize = FileSize(path);
	if (fileSize < 0)
	{
		LogError("Failed to stat cfg file: %s", path);
		return FIX_FAILED;
	}

	if (fileSize == 0)
	{
		return FIX_UNCHANGED;
	}

	File inputFile = OpenFile(path, "rb");
	if (inputFile == null)
	{
		LogError("Failed to open cfg file for reading: %s", path);
		return FIX_FAILED;
	}

	int insertions = CountNeededCommentInsertionsStream(inputFile);
	delete inputFile;

	if (insertions == 0)
	{
		return FIX_UNCHANGED;
	}

	char tempPath[PLATFORM_MAX_PATH];
	char backupPath[PLATFORM_MAX_PATH];
	if (!MakeSuffixedPath(path, TEMP_SUFFIX, tempPath, sizeof(tempPath))
		|| !MakeSuffixedPath(path, BACKUP_SUFFIX, backupPath, sizeof(backupPath)))
	{
		LogError("Cfg temp path is too long: %s", path);
		return FIX_FAILED;
	}

	if (FileExists(tempPath) && !DeleteFile(tempPath))
	{
		LogError("Failed to remove stale temp cfg file: %s", tempPath);
		return FIX_FAILED;
	}

	inputFile = OpenFile(path, "rb");
	if (inputFile == null)
	{
		LogError("Failed to reopen cfg file for reading: %s", path);
		return FIX_FAILED;
	}

	File outputFile = OpenFile(tempPath, "wb");
	if (outputFile == null)
	{
		delete inputFile;
		LogError("Failed to open temp cfg file for writing: %s", tempPath);
		return FIX_FAILED;
	}

	bool wrote = WriteFixedContentStream(inputFile, outputFile);
	outputFile.Flush();
	delete inputFile;
	delete outputFile;

	if (!wrote)
	{
		DeleteFile(tempPath);
		LogError("Failed to write temp cfg file: %s", tempPath);
		return FIX_FAILED;
	}

	if (!ReplaceFileWithTemp(path, tempPath, backupPath))
	{
		DeleteFile(tempPath);
		return FIX_FAILED;
	}

	return FIX_CHANGED;
}

bool MakeSuffixedPath(const char[] path, const char[] suffix, char[] output, int maxLength)
{
	if (strlen(path) + strlen(suffix) + 1 > maxLength)
	{
		return false;
	}

	FormatEx(output, maxLength, "%s%s", path, suffix);
	return true;
}

bool ReplaceFileWithTemp(const char[] path, const char[] tempPath, const char[] backupPath)
{
	if (FileExists(backupPath) && !DeleteFile(backupPath))
	{
		LogError("Failed to remove stale backup cfg file: %s", backupPath);
		return false;
	}

	if (!RenameFile(backupPath, path))
	{
		LogError("Failed to move cfg file to backup: %s", path);
		return false;
	}

	if (!RenameFile(path, tempPath))
	{
		LogError("Failed to move temp cfg file into place: %s", path);
		if (!RenameFile(path, backupPath))
		{
			LogError("Failed to restore backup cfg file: %s", backupPath);
		}
		return false;
	}

	if (FileExists(backupPath) && !DeleteFile(backupPath))
	{
		LogError("Failed to remove backup cfg file after replacement: %s", backupPath);
	}

	return true;
}

int CountNeededCommentInsertionsStream(File inputFile)
{
	int insertions;
	bool inChineseRun;
	bool hasPendingByte;
	int pendingByte;

	int unit[UTF8_MAX_BYTES];
	int unitLength;
	int codepoint;
	bool validUtf8;

	while (ReadNextUnit(inputFile, hasPendingByte, pendingByte, unit, unitLength, codepoint, validUtf8))
	{
		if (validUtf8 && IsChineseRelatedCodepoint(codepoint))
		{
			inChineseRun = true;
			continue;
		}

		if (inChineseRun)
		{
			if (ShouldInsertBeforeUnit(unit, unitLength, inputFile, hasPendingByte, pendingByte))
			{
				insertions++;
			}

			inChineseRun = false;
		}
	}

	if (inChineseRun)
	{
		insertions++;
	}

	return insertions;
}

bool WriteFixedContentStream(File inputFile, File outputFile)
{
	bool inChineseRun;
	bool hasPendingByte;
	int pendingByte;

	int unit[UTF8_MAX_BYTES];
	int unitLength;
	int codepoint;
	bool validUtf8;

	while (ReadNextUnit(inputFile, hasPendingByte, pendingByte, unit, unitLength, codepoint, validUtf8))
	{
		if (validUtf8 && IsChineseRelatedCodepoint(codepoint))
		{
			inChineseRun = true;
			if (!WriteUnit(outputFile, unit, unitLength))
			{
				return false;
			}
			continue;
		}

		if (inChineseRun)
		{
			if (ShouldInsertBeforeUnit(unit, unitLength, inputFile, hasPendingByte, pendingByte)
				&& !WriteCommentSlashes(outputFile))
			{
				return false;
			}

			inChineseRun = false;
		}

		if (!WriteUnit(outputFile, unit, unitLength))
		{
			return false;
		}
	}

	if (inChineseRun && !WriteCommentSlashes(outputFile))
	{
		return false;
	}

	return true;
}

bool ShouldInsertBeforeUnit(const int[] unit, int unitLength, File inputFile, bool &hasPendingByte, int &pendingByte)
{
	if (unitLength < 1 || unit[0] != '/')
	{
		return true;
	}

	int nextByte;
	if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, nextByte))
	{
		return true;
	}

	PushPendingByte(hasPendingByte, pendingByte, nextByte);
	return nextByte != '/';
}

bool ReadNextUnit(File inputFile, bool &hasPendingByte, int &pendingByte, int unit[UTF8_MAX_BYTES], int &unitLength, int &codepoint, bool &validUtf8)
{
	int first;
	if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, first))
	{
		return false;
	}

	unit[0] = first;
	unitLength = 1;
	codepoint = first;
	validUtf8 = true;

	if (first < 0x80)
	{
		return true;
	}

	if ((first & 0xE0) == 0xC0)
	{
		int second;
		if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, second))
		{
			validUtf8 = false;
			return true;
		}

		unit[unitLength++] = second;
		if (!IsUtf8Continuation(second))
		{
			validUtf8 = false;
			return true;
		}

		codepoint = ((first & 0x1F) << 6) | (second & 0x3F);
		validUtf8 = codepoint >= 0x80;
		return true;
	}

	if ((first & 0xF0) == 0xE0)
	{
		int second;
		int third;
		if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, second))
		{
			validUtf8 = false;
			return true;
		}

		unit[unitLength++] = second;
		if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, third))
		{
			validUtf8 = false;
			return true;
		}

		unit[unitLength++] = third;
		if (!IsUtf8Continuation(second) || !IsUtf8Continuation(third))
		{
			validUtf8 = false;
			return true;
		}

		codepoint = ((first & 0x0F) << 12) | ((second & 0x3F) << 6) | (third & 0x3F);
		validUtf8 = codepoint >= 0x800;
		return true;
	}

	if ((first & 0xF8) == 0xF0)
	{
		int second;
		int third;
		int fourth;
		if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, second))
		{
			validUtf8 = false;
			return true;
		}

		unit[unitLength++] = second;
		if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, third))
		{
			validUtf8 = false;
			return true;
		}

		unit[unitLength++] = third;
		if (!ReadNextByte(inputFile, hasPendingByte, pendingByte, fourth))
		{
			validUtf8 = false;
			return true;
		}

		unit[unitLength++] = fourth;
		if (!IsUtf8Continuation(second) || !IsUtf8Continuation(third) || !IsUtf8Continuation(fourth))
		{
			validUtf8 = false;
			return true;
		}

		codepoint = ((first & 0x07) << 18) | ((second & 0x3F) << 12) | ((third & 0x3F) << 6) | (fourth & 0x3F);
		validUtf8 = codepoint >= 0x10000 && codepoint <= 0x10FFFF;
		return true;
	}

	validUtf8 = false;
	return true;
}

bool ReadNextByte(File inputFile, bool &hasPendingByte, int &pendingByte, int &value)
{
	if (hasPendingByte)
	{
		value = pendingByte;
		hasPendingByte = false;
		return true;
	}

	return inputFile.ReadUint8(value);
}

void PushPendingByte(bool &hasPendingByte, int &pendingByte, int value)
{
	pendingByte = value;
	hasPendingByte = true;
}

bool WriteUnit(File outputFile, const int[] unit, int unitLength)
{
	for (int i = 0; i < unitLength; i++)
	{
		if (!outputFile.WriteInt8(unit[i]))
		{
			return false;
		}
	}

	return true;
}

bool WriteCommentSlashes(File outputFile)
{
	return outputFile.WriteInt8('/') && outputFile.WriteInt8('/');
}

bool IsUtf8Continuation(int value)
{
	return (value & 0xC0) == 0x80;
}

bool IsChineseRelatedCodepoint(int codepoint)
{
	return (codepoint >= 0x3400 && codepoint <= 0x4DBF)
		|| (codepoint >= 0x4E00 && codepoint <= 0x9FFF)
		|| (codepoint >= 0xF900 && codepoint <= 0xFAFF)
		|| (codepoint >= 0x3000 && codepoint <= 0x303F)
		|| (codepoint >= 0xFE30 && codepoint <= 0xFE4F)
		|| (codepoint >= 0xFF00 && codepoint <= 0xFFEF);
}
