#!/usr/bin/php-cli
<?php
/*
 * --------------------------------------------------------------------------------
 * cleanupsource.php
 * 	Copyright    : Copyright (C) 2003 Shigeyuki Yamashita <shige@cty-net.ne.jp>
 *  Time-Stamp   : 2003-08-12
 *  License      : GPL2
 * --------------------------------------------------------------------
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * version 2 as published by the Free Software Foundation.
 * --------------------------------------------------------------------
 *
 * kaz���� ruby�ǽ񤫤줿 cleanupsource �� php �ǽ񤤤Ƥߤ�
 * (�¤� cleanupsource �λȤ������ɤ����ʤ��ä��ΤǼ�ʬ���Ȥ���褦�ˡġ�)
 *
 * [����]
 *
 *  ���� SRPMS �ˤ��� rpm �Υӥ�ɤ�ɬ�פȤ��Ƥ��ʤ���������ꥹ�ȥ��å� & �������
 * ����OmoiKondara��Ĺǯ�ӥ�ɤ򷫤��֤��Ƥ���ȡ�������spec�ǤϻȤäƤ��ʤ��Ť�����
 * ���� SOURCES�ǥ��쥯�ȥ�˻�¸���ޤ����������ɬ��̵���ե������ SRPM�ξ������
 * �ꥹ�ȥ��åפ�������ޤ���
 *
 * kaz���󤬽񤫤줿 cleanupsource ��Ʊ��ư��򤹤�ΤǤ�������� ruby ����餺���ɤ�
 * ��������ꤷ�Ƥ����Τ����ʤ��ä��Τǡ���ʬ���Ȥ��䤹���ͤ� php ��Ʊ���褦��ư��
 * �򤹤륹����ץȤ�������ޤ�����
 *
 * Momonga Project�� Ruby�ޥ�������¿���Τ� php �Υ�����ץȤ����ˤ⤵��ʤ�(or ����)
 * �Ȼפ��뤫���Τ�ʤ��Ǥ����ġġ�
 *
 *
 * [ư��]
 *
 *  1. SRPMS�ˤ��� *.(nosrc|src).rpm �� rpm -qpl ��ȯ�Ԥ��������ե������ꥹ�Ȥ��롥
 *
 *  2. Ʊ����Ʊ�ե������ rpm2cpio �� cpio �� �ޤޤ�Ƥ��륽�����ե������ꥹ�Ȥ��롥
 *
 *  3. �����ꥹ�Ȥ���ɬ�פȤ��Ƥ��ʤ��ե������ꥹ�ȥ��åפ���������ޤ���
 *
 * [�ʲ���ħ!?]
 *
 *  - �ե�����ꥹ�ȤΥƥ�ݥ��ե������񤭽Ф��ʤ�
 *
 *  - ��Ĺ�ǥ�����
 *
 *  - Ruby�ޥ�������¿�� Momonga Project �Ǥ� php �ǽ񤤤Ƥ����ˤ��Ƥ�館�ʤ�
 *
 *  - LANG=ja_JP.EUC-JP �ʴĶ�����ʤ��ȥ�å�������������
 *
 *  - php-cli�ѥå����������󥹥ȡ��뤵��Ƥʤ��ȻȤ��ʤ�
 *
 *  - ���顼������������
 *
 * --------------------------------------------------------------------------------
 */

/*
 * ===== ���ڥǥ��쥯�ȥ���� =====
 */
$srpmsdir = "";
$srcdir   = "";

/* -----  / (�롼��) ��������Хѥ����׵� ----- */
$srpmsdir_regex = '^/.+/SRPMS$';
$srcdir_regex = '^/.+/SOURCES$';

if ($argv[1] != "") {
	$argv[1] = trim($argv[1]);
	if(preg_match("'--?(help|h|\?)'",$argv[1])) {
		// �إ�� �ߡ� �餷����
		fwrite(STDERR,"���ڤ��� SRPMS �ǥ��쥯�ȥ�� / ��������Хѥ��ǻ��ꤷ�Ƥ���������\n");
		fwrite(STDERR,"Usage: {$argv[0]} <SRPMS directry>\n");
		exit();
	}
	else {
		$srpmsdir = preg_replace("'/$'","",$argv[1]);
		// �ǥ��쥯�ȥ�������ʸ����� SRPMS �ǽ��äƤ���Ȧ
		if (!preg_match("'{$srpmsdir_regex}'",$srpmsdir)) {
			fwrite(STDERR,"���Ϥ�����������ޤ���\n");
			list($srpmsdir,$srcdir) = get_path();
		}
		else {
			// �ǡ�����ʤ顤SOURCES �ǥ��쥯�ȥ�� Ʊ���ؤ� SOURCES ����
			$srcdir = preg_replace("'SRPMS$'","SOURCES",$srpmsdir);
		}
		// �����ǧ�ΰ� ʹ���Ƥߤ�
		fwrite(STDERR,"SRPMS   �� $srpmsdir\n");
		fwrite(STDERR,"SOURCES �� $srcdir\n");
		fwrite(STDERR,"���ڤ���ǥ��쥯�ȥ�Ͼ嵭�ǵ������Ǥ���? [Y/n] : ");
		$dir_ok = "";
		$dir_ok = trim(fgets(STDIN,4));
		if(!preg_match("'^(y|yes)$'i",$dir_ok)) {
			// ���㤦�餷���ΤǸ��ڥǥ��쥯�ȥ��ξ��ʹ���Ƥߤ�
			list($srpmsdir,$srcdir) = get_path();
		}
		else {
			fwrite(STDERR,"�����ǥ��쥯�ȥ���򸡾ڤ��ޤ���\n");
		}
	}
}
else {
	// �����ʤ��ǸƤФ����ä��ΤǸ��ڥǥ��쥯�ȥ��ξ��ʹ���Ȥ�
	list($srpmsdir,$srcdir) = get_path();
}

/*
 * ===== SRPM ����ꥹ�Ȥ����� =====
 */
$src_list = array();
chdir($srpmsdir);
$d = false;
$d = dir($srpmsdir);

if($d !== false) {
	while(false !== ($srpm = $d->read())) {
		$cpio_list = array();
		$qpl_list = array();
		if (preg_match("|^.*.rpm$|",$srpm)) {
			$qpl_list = preg_split("'\n+'", `rpm -qpl $srpm`);
			$cpio_list = preg_split("'\n+'", `rpm2cpio $srpm | cpio --list 2>/dev/null`);
			foreach ($qpl_list as $src) {
			// rpm -qpl �ǥꥹ�Ȥ���뤬 rpm �ե�����˴ޤޤ�Ƥʤ��������� src_list��
				if(!in_array($src, $cpio_list)) {
					array_push($src_list,$src);
				}
			}
		}
	}
	$d->close();
	unset($d);
}
else {
	// ������ɤ�ʤ��衼
	fwrite(STDERR,"{$srpmsdir} ���ɤ�ޤ���\n");
	exit();
}

/*
 * ===== SOURCES�ǥ��쥯�ȥ꤫��ե�����Υꥹ�Ȥ�����  =====
 */
chdir($srcdir);
$d = false;
$d = dir($srcdir);

if ($d !== false) {
	$src_files = array();
	while(false !== ($file = $d->read())) {
		$src_file = trim($file);
		//  . �Ȥ� .. �Ȥ������
		if (!preg_match("'^(?:\.|\.\.)$'",$src_file)) {
			array_push($src_files,$src_file);
		}
	}
	$d->close();
	unset($d);
}
else {
	// ������ɤ�ʤ��衼
	fwrite(STDERR,"{$srcdir} ���ɤ�ޤ���\n");
	exit();
}

/*
 * ===== ��������ꥹ�Ȥ���;�꥽�����ե������Ĵ�٤� =====
 */
$surplus_list = array();
foreach($src_files as $src_file) {
	if (!in_array($src_file, $src_list)) { // in_array ���϶ȡ�
		array_push($surplus_list, $src_file);
	}
}

if (count($surplus_list) == 0) {
	fwrite(STDERR,"������٤�;�꥽�����ե�����Ϥ���ޤ���\n\n���֤�ġġ�\n");
	exit();
}
else {
	// Ĵ�٤���̤� $HOME/source_surpluses �ؽ񤭻Ĥ�
	$surpluses = join("\n",$surplus_list);
	$surplus_list_file = $_ENV['HOME'] . '/source_surpluses';
	$f = fopen($surplus_list_file, "w");
	if ($f == false) {
		// ��ʬ�� $HOME �إե����뤬�񤭽Ф��ʤ����Ϥ��ޤ�̵���Ȼפ�����
		fwrite(STDERR, ";�꥽�����Υꥹ�Ȥ�񤭽Ф��ޤ���\n");
		// ���������������פ�Ĥ��ʤ�(��������ꥹ�Ȥ�Ĥ����Ǥ��ݤ�)�Τ� exit ���ޤ���
		exit();
	}
	else {
		fwrite($f,$surpluses . "\n");
		fwrite(STDERR, ";�꥽�����Υꥹ�Ȥ� $surplus_list_file �ؽ񤭽Ф��ޤ�����\n");
		// ������뤫�ɤ���ʹ���Ƥߤ� (�־���˺������ʥ��륡���к�)
		fwrite(STDERR, $surpluses . "\n\n�����ե�����������ޤ���? [y/N] : ");
		$del_ok = "";
		$del_ok = fgets(STDIN,4);
		if (preg_match("'^(y|yes)$'i",$del_ok)) {
			foreach($surplus_list as $surplus) {
				if (unlink($surplus)) { // unlink�����ʤ�
					// �����������(���ʤꥦ����?)
					fwrite(STDERR, $surplus . " �������ޤ�����\n");
				}
				else { // ���餫����ͳ��unlink�Ǥ��ʤ�
					fwrite(STDERR, $surplus . " �����Ǥ��ޤ���\n");
				}
			}
		}
		else { // ����˺���ϥ��䡼��餷���ġ�
			fwrite(STDERR,"���������λ���ޤ���\n");
		}
	}
}

exit(); // ��λ


/*
 * ----------------------------------------------------------------------
 * ���ڤ��� SRPMS��SOURCES�� �ѥ������Ϥ��Ƥ�餦
 * ----------------------------------------------------------------------
 */

function get_path() {
	global $srpmsdir_regex,$srcdir_regex;
	fwrite(STDERR,"���ڤ��� SRPMS�ǥ��쥯�ȥ�� / ��������Хѥ��ǻ��ꤷ�Ʋ�������\n");
	$srpmsdir = get_path_input($srpmsdir_regex);
	fwrite(STDERR,"���ڤ��� SOURCES�ǥ��쥯�ȥ�� / ��������Хѥ��ǻ��ꤷ�Ʋ�������\n");
	$srcdir = get_path_input($srcdir_regex);
	return array($srpmsdir,$srcdir);
}

function get_path_input($regex) {
	$directory = trim(fgets(STDIN,128));
	$directory = preg_replace("'/$'","",$directory);
	if (preg_match("'{$regex}'",$directory)) {
		return $directory;
	}
	else {
		fwrite(STDERR,"���Ϥ�����������ޤ��󡥤⤦�������Ϥ��Ʋ�������\n");
		get_path_input($regex);
	}
}


/*
 *  end of script
 */
?>