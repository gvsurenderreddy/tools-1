coMomonga�Υǥ��������᡼�����ä��㤦������ץ�

���顼�������褦�ȡ��ߤޤ餺���ͤ��ʤߤޤ���
�����ѤκݤϤ���դ���������

ɬ�פ�ʪ

1.ruby
2.rpm�ե�������֤������/tmp��1G�ʾ�ζ����ΰ�
  (������ץȤν������̤Υǥ��쥯�ȥ�ؤ��ѹ���Ǥ��ޤ�)


�Ȥ���(coLinux��)

1.���󥹥ȡ�����Υ��᡼���ե������dd���뤫��
  http://dist.momonga-linux.org/pub/momonga/1/i586/colinux/��ext3_XXX.img.bz2�դ꤫����äƤ���
2.coLinux������ե�����˰ʲ��Τ褦�ʹԤ��ɲä��ơ����󥹥ȡ����襤�᡼���ե������"/dev/cobd2"�˳�꿶��
   <block_device index="2" path="\DosDevices\c:\coLinux\coMomo-new.img" enabled="true" />

3./tmp��1G���٤ζ�����ͭ������ǧ����
4.momo.sh��¹ԡ����顼���Ф��˥�����ץȤ���λ�����齪λ�Ǥ���


�Ȥ���(���̤�Linux��)

1.dd������Ѥ��ƥ��󥹥ȡ����襤�᡼���ե������������롣
2."momo.sh"�ΰʲ�����ʬ��������

  a.���󥹥ȡ������ǥ��������᡼���ˤ���
    momo.sh��5�����դ�

        (��)
        TARGETDISK="/dev/cobd2"  -> TARGETDISK="/home/meke/coMomo/momo-dev.img"
       
  b.�ޥ���ȤΥ��ץ������ѹ����롣
    momo.sh��70�����դ�

        # image file
        # mount -o loop -t ext3 $TARGETDISK $TARGETDIR
        
        # block device
        mount -t ext3 $TARGETDISK $TARGETDIR

	�����

        # image file
        mount -o loop -t ext3 $TARGETDISK $TARGETDIR
        
        # block device
        # mount -t ext3 $TARGETDISK $TARGETDIR


3./tmp��1G���٤ζ�����ͭ������ǧ����
4.momo.sh��¹ԡ����顼���Ф��˥�����ץȤ���λ�����齪λ�Ǥ���

