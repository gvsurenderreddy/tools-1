#!/usr/bin/php-cli
<?php
/*
 * --------------------------------------------------------------------------------
 *  gnu_md5sum_check.php
 *
 *  Copyright : Copyright (C) 2003 Shigeyuki
 *  Yamashita <shige@cty-net.ne.jp>
 *  Time-Stamp : 2003-08-12
 *  License : GPL2
 *
 *  --------------------------------------------------------------------
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  version 2 as published by the Free Software Foundation.
 *  --------------------------------------------------------------------
 *
 *
 * [����]
 *
 *  gnu ftp�����ФǸ�������Ƥ��������ǧ�ꥹ�Ȥȥ��������Ƥ���
 *  �ե������ md5sum�ͤθ��ڤ�Ԥʤ���
 *  see. http://ftp.gnu.org/MISSING-FILES.README
 *       http://www.cert.org/advisories/CA-2003-21.html
 *
 *
 * [ư��]
 *
 *  1. ���ꤵ�줿 SOURCES�ǥ��쥯�ȥ�Υե������ꥹ�ȥ��åס�
 *
 *  2. ���ۤ���Ƥ���ե�������Ф���md5 checksum�ΰ�����ǧ�ꥹ�Ȥ���
 *     �߹��ࡥ
 *
 *     ������ǧ�ꥹ�� �� ftp://ftp.gnu.org/before-2003-08-01.md5sums.asc
 *                       ftp://alpha.gnu.org/before-2003-08-01.md5sums.asc
 *
 *  3. ������Υե�����̾��������ǧ�ꥹ�Ȥˤ���С�����md5sum�ȥ�
 *     ����ˤ��륽������md5sum��ȹ�
 *
 *  4. ���ڷ�̤� $HOME/gnu_ftp_md5sum_check_result �˽񤭽Ф���
 *
 * --------------------------------------------------------------------------------
 */

/*
 * ===== ���ڥǥ��쥯�ȥ���� =====
 */

function print_usage() {
	$me = basename($_SERVER["SCRIPT_NAME"]);
	$msg = <<<MSG
���ڤ��� SOURCES �ǥ��쥯�ȥ�Ȱ�����ǧ�ꥹ�ȤΥѥ�(or URL)����ꤷ�Ʋ�������

Usage:
	{$me} <SOURCES directry> <md5sums.asc��path or URL>

[��]
\$ {$me} /hoge/PKGS/SOURCES ftp://ftp.gnu.org/before-2003-08-01.md5sums.asc


MSG;

	fwrite(STDERR,$msg);
}

/*
 * md5sums.asc ���ɤ߹���� �ե�����̾�򥭡��Ȥ��� filename => md5sum
 * ��Ϣ�����������
 */
function get_md5sums($filepath) {
	$tmpdata = array();
	$tmpdata = file($filepath);
	if(count($tmpdata) == 0) {
		fwrite(STDERR,"md5sum�Υꥹ�Ȥ�����Ǥ��ޤ���");
		exit();
	}
	$md5sums = array();
	$begin_msg = '-----BEGIN PGP SIGNED MESSAGE-----';
	$begin_pgp_sign = '-----BEGIN PGP SIGNATURE-----';

	foreach($tmpdata as $line) {
		if(preg_match("'^{$begin_pgp_sign}$'",$line)) {
			break;
		}
		else if(preg_match("'^(?:{$begin_msg}|Hash:.*|\s)$'",$line)) {
			continue;
		}
		else {
			$md5sum = "";
			$ftppath = "";
			$comment = "";
			$filename = "";
			// ���� or tab���ڤ꤫�Ȼפ���ΤǶ���ʸ���ǹԤ�3ʬ��
			// �Ǥ� $comment�Ϸ�ɤ����Ѥ��ʤ�
			list($md5sum,$ftppath,$comment) = preg_split("'\s+'",$line,3,PREG_SPLIT_NO_EMPTY);
			// �ե�����̾�򥭡��ˤ���Ϣ�������
			$filename = basename($ftppath);
			// fwrite(STDERR,"{$filename} : {$md5sum}\n"); // debug��
			$md5sums["{$filename}"] = $md5sum;
		}
	}
	return $md5sums;
}

/*
 *  SOURCES�ǥ��쥯�ȥ�Υ������ե������ꥹ�ȥ��åפ���
 */
function get_srcfiles($srcdir) {
	chdir($srcdir);
	$d = false;
	$d = dir($srcdir);

	if ($d !== false) {
		$srcfiles = array();
		while(false !== ($file = $d->read())) {
			$srcfile = trim($file);
			//  . �Ȥ� .. �Ȥ������
			if (!preg_match("'^(?:\.|\.\.)$'",$srcfile)) {
				array_push($srcfiles,$srcfile);
			}
		}
		$d->close();
		unset($d);
		natsort($srcfiles);
		return $srcfiles;
	}
	else {
		// ������ɤ�ʤ��衼
		fwrite(STDERR,"{$srcdir} ���ɤ�ޤ���\n");
		exit();
	}
}


// main
if (($argc < 2) || preg_match("'--?(help|h|\?)'",$argv[1])) {
	print_usage();
	exit();
}
else {
	$srcdir = preg_replace("'/$'","",$argv[1]);
	$md5sum_file = trim($argv[2]);
	if(!is_dir($srcdir)) {
		fwrite(STDERR,"{$srcdir}�ϥǥ��쥯�ȥ�ǤϤʤ�����¸�ߤ��ޤ���");
		exit();
	}
	$srcfiles = array();
	$md5sums = array();
	$srcfiles = get_srcfiles($srcdir);
	$md5sums = get_md5sums($md5sum_file);
	$danger_files = array();
	$unverifying  = array();
	$verifying    = array();
	$result = "";
	$result_file = $_ENV["HOME"] . '/gnu_ftp_md5sum_check_result';
	foreach($srcfiles as $srcfile) {
		if (!array_key_exists($srcfile,$md5sums)) {
			array_push($unverifying,"{$srcdir}/{$srcfile}");
		}
		else {
			$src_md5sum = "";
			$src_md5sum = md5_file($srcfile);
			$gnu_md5sum = "";
			$gnu_md5sum = $md5sums["{$srcfile}"];
			// debug start
			// fwrite(STDERR,"{$srcfile} �򸡾�\n");
			// fwrite(STDERR,"������ {$src_md5sum} <=> �ꥹ�� {$gnu_md5sum}\n\n");
			// debug end

			if (strcmp($src_md5sum,$gnu_md5sum) == 0) {
				array_push($verifying,"{$srcdir}/{$srcfile}");
			}
			else {
				array_push($danger_files,"{$srcdir}/{$srcfile}");
			}
		}
	}
	$sep = "#---------------------------------------------------------------------\n";
	$result .= $sep;
	$result .= "# {$md5sum_file}\n";
	$result .= "# �Υꥹ�Ȥ��ˡ�\n";
	$result .= "# {$srcdir}\n";
	$result .= "# �ˤ��륽������ md5sum���ڤ�Ԥʤ��ޤ�����\n";
	$result .= $sep . "\n\n" . $sep;
	$result .= "# [Safety] �ꥹ�Ȥ���Ƥ���md5sum�����פ����Ρ�\n";
	$result .= $sep;
	$result .= join("\n",$verifying) . "\n\n";
	$result .= $sep;
	$result .= "# [Danger?] �ꥹ�Ȥ� md5sum �Ȱ��פ��ʤ���Ρ�\n";
	$result .= $sep;
	$result .= join("\n",$danger_files) . "\n\n";
	$result .= $sep;
	$result .= "# [unverifying]\n";
	$result .= "# �ꥹ�Ȥ���Ƥ��ʤ���� or GNU �Υ������ǤϤʤ����\n";
	$result .= $sep;
	$result .= join("\n",$unverifying) . "\n\n";
	// Ĵ�٤���̤� $HOME/gnu_ftp_md5sum_check_result �ؽ񤭽Ф���
	$fp = fopen($result_file,"w");
	if ($fp == false) {
		// ��ʬ�� $HOME �إե����뤬�񤭽Ф��ʤ����Ϥ��ޤ�̵���Ȼפ�����
		fwrite(STDERR, "���ڷ�̤�񤭽Ф��ޤ���\n");
	}
	else {
		if (fwrite($fp,$result)) {
			fwrite(STDOUT,$result . "\n\n");
			fwrite(STDERR, "���ڷ�̤� {$result_file} �ؽ񤭽Ф��ޤ�����\n");
		}
		else {
			fwrite(STDERR, "���ڷ�̤�񤭽Ф��ޤ���\n");
		}
	}
	exit();
}

/*
 *  end of script
 */
?>