# Garmin540RideNB 1.0

Garmin Edge 540 / 540 Solar 全屏 Connect IQ 数据字段，246×322。

## 安装

将 Garmin540RideNB.prg 复制到 GARMIN/APPS，并选择单字段全屏布局 → Connect IQ → Garmin540RideNB。应用 ID 沿用旧版，安装升级时请移除原 RideMosaic540.prg，避免重复字段；原配置可继续复用。安全弹出并重启设备。

## 数据与界面

普通页：12 小时当前时间（am/pm）、骑行时间、距离、总爬升、速度与全程均速、三秒功率与全程均功率、心率、踏频、坡度，以及圈均功率、圈均速、圈时间和距离。

冲刺页：速度、即时功率、踏频、心率、骑行时间五行居中。进入判定仍使用三秒平均功率，默认达到600W进入；连续低于550W三秒返回，功率缺失五秒返回。配置可修改阈值、自动切换开关与缺失超时。

## RGB222 配色

| 数据 | 色值 |
|---|---|
| 功率 | #5500AA |
| 速度 | #0055AA |
| 心率 | #AA0000 |
| 踏频 | #00AA55 |
| 坡度与爬升 | #AA5500 |
| 当前时间 | #555555 |
| 骑行及圈时间、距离 | #000000 |
| 背景 / 色块白字 | #FFFFFF |

应用指定色值均为 RGB222，硬件对字体抗锯齿过渡色及屏幕颜色的处理由 Garmin 渲染器决定。

## 设置

IQ 应用设置支持进入阈值1–10000W。码表端设置页上下键以10W调整，Enter保存并显示确认；未保存修改时Back询问继续编辑或放弃退出。设置视图用页面替换触发重绘，避免部分固件忽略requestUpdate。该绕过方式仍需真机复核，之前逐秒绘制测试容器不能证明固件设置页的刷新行为。

## 构建与测试

需要 Connect IQ SDK 9.3.0 和 Edge540 设备定义。包含生成后的字体，正常构建无需 Python。

```sh
CIQ_SDK=/path/to/sdk CIQ_KEY=/private/developer.der bash tools/build.sh --tests
$CIQ_SDK/bin/monkeydo bin/Garmin540RideNB-tests.prg edge540 -t
python tools/check_layout.py
```

签名私钥不提交。默认在 .keys/ 创建本地密钥。由于SDK渐进类型检查器异常，使用 -l 0 编译。字体基于 Titillium Web Bold，许可证见 assets/OFL.txt。

圈数据、断连、暂停、低速坡度、存储恢复、阈值切换和设置确认有自动回归。首次骑行途中加载无法恢复未记录的圈历史；坡度为距离/海拔差自行计算，非 Garmin 原生坡度。模拟器验证不能替代真机日光可读性与长时间稳定性验证。
