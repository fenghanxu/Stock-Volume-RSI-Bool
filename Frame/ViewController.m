

#import "ViewController.h"
#define viewHeight 300 // 蜡烛图高度
#define space 3 // 每条蜡烛图的间隙
#define MaxVisibleKLineCount 300 // 每次提取限制300个数据
#define MaxCacheKLineCount 600 // 数组限制最多600个可视数据
#define volumeHeight 80  // 成交量图形高度
#define rsiHeight 60 // RSI 指标高度

#define TP_Parameter 0.059
#define SL_Parameter 0.017

//k线模型
@interface KLineModel : NSObject
@property (nonatomic, assign) CGFloat open;
@property (nonatomic, assign) CGFloat high;
@property (nonatomic, assign) CGFloat low;
@property (nonatomic, assign) CGFloat close;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) CGFloat volume;
@property (nonatomic, assign) CGFloat rsi; // 新增 RSI 属性
@property (nonatomic, assign) CGFloat bollUpper;
@property (nonatomic, assign) CGFloat bollMiddle;
@property (nonatomic, assign) CGFloat bollLower;
@property (nonatomic,   copy) NSString *signalTag;   // 标记“买入”

@end

@implementation KLineModel
@end

typedef void(^KLineScaleAction)(BOOL clickState);

@interface KLineChartView : UIView
//可视view的数据，限制最多900条蜡烛图(总的数据当中的一部分)
@property (nonatomic, strong) NSArray<KLineModel *> *visibleKLineData;
//可视图x的偏移值，(可视图相对总图的x显示位置)
@property (nonatomic, assign) CGFloat contentOffsetX;
//蜡烛图的宽度
@property (nonatomic, assign) CGFloat candleWidth;
//长按手势:是否显示虚线
@property (nonatomic, assign) BOOL showCrossLine;
//长按手势相关: 十字线的point点
@property (nonatomic, assign) CGPoint crossPoint;
//长按手势相关
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture;
//捏合手势
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGesture;

@end

@implementation KLineChartView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        //初始化蜡烛图宽度
        _candleWidth = 8;
        //长按手势初始化
        _longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        _longPressGesture.minimumPressDuration = 0.3;
        _longPressGesture.allowableMovement = 15;
        [self addGestureRecognizer:_longPressGesture];
        //捏合手势初始化
        _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        [self addGestureRecognizer:_pinchGesture];
    }
    return self;
}

//长按手势处理
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self];
    
    if (gesture.state == UIGestureRecognizerStateBegan ||
        gesture.state == UIGestureRecognizerStateChanged) {
        self.showCrossLine = YES;
        self.crossPoint = point;
        [self setNeedsDisplay];
    } else {
        self.showCrossLine = NO;
        [self setNeedsDisplay];
    }
}

//捏合手势处理
/**
 1.捏合根据gesture.scale 转换成  缩放比例，缩放蜡烛图的大小
 2.重新计算  scrollView 的 contentSize 和 contentOffset
 3.缩放目标保持在中间不动(写得不好)
 */
- (void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    static CGFloat lastScale = 1.0;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        lastScale = 1.0;
    }

    CGFloat scale = gesture.scale / lastScale;
    lastScale = gesture.scale;

    // 限制 candleWidth 范围
    CGFloat newWidth = self.candleWidth * scale;
    newWidth = MAX(2, MIN(newWidth, 40));

    if (fabs(newWidth - self.candleWidth) < 0.01) return;

    // 找到手势中心点在 chartView 中的坐标
    CGPoint pinchCenterInView = [gesture locationInView:self];
    CGFloat centerX = pinchCenterInView.x;

    // 旧宽度下的 index
    NSInteger oldIndex = centerX / (self.candleWidth + space);

    // 旧相对偏移比例（在 scrollView 中）
    CGFloat ratio = (centerX) / self.bounds.size.width;

    // 更新 candleWidth
    self.candleWidth = newWidth;

    // 更新自身 frame 宽度
    CGFloat newChartWidth = self.visibleKLineData.count * (self.candleWidth + space);
    CGRect frame = self.frame;
    frame.size.width = newChartWidth;
    self.frame = frame;

    // 更新 scrollView 的 contentSize 和 contentOffset
    if ([self.superview isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        scrollView.contentSize = CGSizeMake(newChartWidth, scrollView.contentSize.height);

        // 重新计算缩放后的偏移
        CGFloat newOffsetX = oldIndex * (self.candleWidth + space) - ratio * scrollView.bounds.size.width;
        newOffsetX = MAX(0, MIN(newOffsetX, scrollView.contentSize.width - scrollView.bounds.size.width));
        scrollView.contentOffset = CGPointMake(newOffsetX, 0);
    }

    [self setNeedsDisplay];
}

- (void)setContentOffsetX:(CGFloat)contentOffsetX {
    _contentOffsetX = contentOffsetX;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    if (!self.visibleKLineData || self.visibleKLineData.count == 0) return;

    // 创建绘图上下文（画布对象）“画布 + 画笔 + 样式设置”
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    // 可视view  显示的个数
    NSInteger countInView = ceil(SCREEN_WIDTH / (self.candleWidth + space)) + 1;
    // 可视view  开始的index
    NSInteger startIndex = MAX(0, self.contentOffsetX / (self.candleWidth + space));
    // 可视view  结束的index
    NSInteger endIndex = MIN(startIndex + countInView, self.visibleKLineData.count);

    // 局部最大最小价
    CGFloat maxPrice  = -MAXFLOAT;
    CGFloat minPrice  = MAXFLOAT;
    CGFloat maxVolume = -MAXFLOAT;

    for (NSInteger i = startIndex; i < endIndex; i++) {
        KLineModel *model = self.visibleKLineData[i];
        maxPrice = MAX(maxPrice, model.high);
        minPrice = MIN(minPrice, model.low);
        maxVolume = MAX(maxVolume, model.volume);
    }

    CGFloat marginRatio = 0.1;
    CGFloat priceRange = maxPrice - minPrice;
    CGFloat padding = priceRange * marginRatio;
    maxPrice += padding;
    minPrice -= padding;

    //求出可视view一格代表多少钱(1格/100元，1格/200元)
    CGFloat scale = viewHeight / (maxPrice - minPrice);
    CGFloat volumeTop = viewHeight + 10;

    // 给文字预留空间（数值高度 + 上边距）
    CGFloat volumeTextGap = 12; // 你可以调整成 8、10、12

    // 重新计算真正可用的绘制高度
    CGFloat volumeDrawHeight = volumeHeight - volumeTextGap;
    if (volumeDrawHeight < 1) volumeDrawHeight = 1;

    // 更新 volumeScale
    CGFloat volumeScale = (maxVolume > 0) ? (volumeDrawHeight / maxVolume) : 0;
    
    CGFloat rsiTop = volumeTop + volumeHeight + 10;

    
    // for循环遍历可视化的绘制数据
    for (NSInteger i = startIndex; i < endIndex; i++) {
        //绘制 K线
        KLineModel *model = self.visibleKLineData[i];
        CGFloat x = i * (self.candleWidth + space);
        CGFloat openY = (maxPrice - model.open) * scale;
        CGFloat closeY = (maxPrice - model.close) * scale;
        CGFloat highY = (maxPrice - model.high) * scale;
        CGFloat lowY = (maxPrice - model.low) * scale;

        UIColor *color = model.close >= model.open ? [UIColor redColor] : [UIColor colorWithRed:0.23 green:0.74 blue:0.52 alpha:1.0];
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        CGContextSetLineWidth(ctx, 1);
        //绘制 上下影线（High-Low）
        CGContextMoveToPoint(ctx, x + self.candleWidth/2, highY);
        CGContextAddLineToPoint(ctx, x + self.candleWidth/2, lowY);
        CGContextStrokePath(ctx);
        //绘制实体 Body（开盘价到收盘价）
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        if (model.close >= model.open) {
            CGContextFillRect(ctx, CGRectMake(x, closeY, self.candleWidth, openY - closeY));
        } else {
            CGContextFillRect(ctx, CGRectMake(x, openY, self.candleWidth, closeY - openY));
        }
        
        // ====== 绘制 RSI-BOLL 买入标记 ======
        if (model.signalTag) {

            NSString *txt = model.signalTag;

            NSDictionary *attr = @{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:10],
                NSForegroundColorAttributeName: [UIColor orangeColor]
            };

            CGSize tsize = [txt sizeWithAttributes:attr];

            CGFloat textX = x + (self.candleWidth - tsize.width) / 2;
            CGFloat textY = highY - tsize.height - 2; // 放在高点上方

            [txt drawAtPoint:CGPointMake(textX, textY) withAttributes:attr];
        }
        
        // 绘制每条k线涨跌幅 显示在蜡烛图的底部的数值
        if (model.open > 0) {
            CGFloat changePercent = ((model.close - model.open) / model.open) * 100;
            NSString *percentText = [NSString stringWithFormat:@"%.1f", changePercent];
            NSDictionary *percentAttr = @{
                NSFontAttributeName: [UIFont systemFontOfSize:8],
                NSForegroundColorAttributeName: color
            };
            CGSize size = [percentText sizeWithAttributes:percentAttr];
            
            // 正确：基于最低价位置绘制文字
            CGFloat textX = x + (self.candleWidth - size.width) / 2;
            CGFloat textY = lowY + 2; // lowY 是最低价对应的 Y 坐标

            [percentText drawAtPoint:CGPointMake(textX, textY) withAttributes:percentAttr];
        }
        
        // 绘制 成交量柱子
        CGFloat volHeight = model.volume * volumeScale;
        CGFloat volY = volumeTop + volumeHeight - volHeight;
        CGContextFillRect(ctx, CGRectMake(x, volY, self.candleWidth, volHeight));
        
        // 绘制 成交量柱上方绘制成交量数值
        if (model.volume > 0) {

            // 两种交替颜色（你可自由调整）
            UIColor *color1 = [UIColor colorWithWhite:0.2 alpha:1];          // 深灰
            UIColor *color2 = [UIColor colorWithRed:0 green:0.45 blue:1 alpha:1]; // 蓝色

            // 根据 index 决定颜色（相邻不同色）
            UIColor *textColor = (i % 2 == 0) ? color1 : color2;

            NSString *volText = [NSString stringWithFormat:@"%.0f", model.volume];
            NSDictionary *volAttr = @{
                NSFontAttributeName: [UIFont systemFontOfSize:7],
                NSForegroundColorAttributeName: textColor
            };

            CGSize volSize = [volText sizeWithAttributes:volAttr];

            CGFloat volTextX = x + (self.candleWidth - volSize.width) / 2;
            CGFloat volTextY = volY - volSize.height - 2;

            // 防止文字被蜡烛图盖住
            if (volTextY > viewHeight + 5) {
                [volText drawAtPoint:CGPointMake(volTextX, volTextY) withAttributes:volAttr];
            }
        }
        
        // ======== 固定 RSI 显示区间 0~100 ========
        CGFloat fixedRSIMax = 100;
        CGFloat fixedRSIMin = 0;
        CGFloat rsiScale = rsiHeight / (fixedRSIMax - fixedRSIMin);

        // 绘制 RSI 曲线
        CGContextSetLineWidth(ctx, 1.0);
        CGContextSetStrokeColorWithColor(ctx, [UIColor purpleColor].CGColor);

        for (NSInteger i = startIndex; i < endIndex - 1; i++) {
            KLineModel *m1 = self.visibleKLineData[i];
            KLineModel *m2 = self.visibleKLineData[i+1];

            CGFloat x1 = i * (self.candleWidth + space) + self.candleWidth/2;
            CGFloat x2 = (i+1) * (self.candleWidth + space) + self.candleWidth/2;

            CGFloat y1 = rsiTop + rsiHeight - (m1.rsi - fixedRSIMin) * rsiScale;
            CGFloat y2 = rsiTop + rsiHeight - (m2.rsi - fixedRSIMin) * rsiScale;

            CGContextMoveToPoint(ctx, x1, y1);
            CGContextAddLineToPoint(ctx, x2, y2);
            CGContextStrokePath(ctx);
        }

        // === RSI 虚线 (20, 80)
        NSArray<NSNumber *> *rsiLevels = @[@20, @80];
        CGContextSetLineWidth(ctx, 0.5);
        CGContextSetStrokeColorWithColor(ctx, [UIColor redColor].CGColor);
        CGFloat dashPattern[] = {4, 2};
        CGContextSetLineDash(ctx, 0, dashPattern, 2);

        for (NSNumber *level in rsiLevels) {
            CGFloat y = rsiTop + rsiHeight - (level.floatValue - fixedRSIMin) * rsiScale;
            CGContextMoveToPoint(ctx, 0, y);
            CGContextAddLineToPoint(ctx, self.bounds.size.width, y);
            CGContextStrokePath(ctx);
        }

        CGContextSetLineDash(ctx, 0, NULL, 0); //关闭虚线

    }
    
    // ========= 画布林线 =========
    CGContextSetLineWidth(ctx, 1.0);

    // 中轨线 (黄色)
    CGContextSetStrokeColorWithColor(ctx, [UIColor yellowColor].CGColor);
    for (NSInteger i = startIndex; i < endIndex - 1; i++) {
        KLineModel *m1 = self.visibleKLineData[i];
        KLineModel *m2 = self.visibleKLineData[i+1];

        if (m1.bollMiddle == 0 || m2.bollMiddle == 0) continue;

        CGFloat x1 = i * (self.candleWidth + space) + self.candleWidth/2;
        CGFloat x2 = (i+1) * (self.candleWidth + space) + self.candleWidth/2;

        CGFloat y1 = (maxPrice - m1.bollMiddle) * scale;
        CGFloat y2 = (maxPrice - m2.bollMiddle) * scale;

        CGContextMoveToPoint(ctx, x1, y1);
        CGContextAddLineToPoint(ctx, x2, y2);
        CGContextStrokePath(ctx);
    }

    // 上轨线 (蓝色)
    CGContextSetStrokeColorWithColor(ctx, [UIColor blueColor].CGColor);
    for (NSInteger i = startIndex; i < endIndex - 1; i++) {
        KLineModel *m1 = self.visibleKLineData[i];
        KLineModel *m2 = self.visibleKLineData[i+1];

        if (m1.bollUpper == 0 || m2.bollUpper == 0) continue;

        CGFloat x1 = i * (self.candleWidth + space) + self.candleWidth/2;
        CGFloat x2 = (i+1) * (self.candleWidth + space) + self.candleWidth/2;

        CGFloat y1 = (maxPrice - m1.bollUpper) * scale;
        CGFloat y2 = (maxPrice - m2.bollUpper) * scale;

        CGContextMoveToPoint(ctx, x1, y1);
        CGContextAddLineToPoint(ctx, x2, y2);
        CGContextStrokePath(ctx);
    }

    // 下轨线 (黑色)
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    for (NSInteger i = startIndex; i < endIndex - 1; i++) {
        KLineModel *m1 = self.visibleKLineData[i];
        KLineModel *m2 = self.visibleKLineData[i+1];

        if (m1.bollLower == 0 || m2.bollLower == 0) continue;

        CGFloat x1 = i * (self.candleWidth + space) + self.candleWidth/2;
        CGFloat x2 = (i+1) * (self.candleWidth + space) + self.candleWidth/2;

        CGFloat y1 = (maxPrice - m1.bollLower) * scale;
        CGFloat y2 = (maxPrice - m2.bollLower) * scale;

        CGContextMoveToPoint(ctx, x1, y1);
        CGContextAddLineToPoint(ctx, x2, y2);
        CGContextStrokePath(ctx);
    }

    
    //长按十字线
    if (self.showCrossLine) {
        NSInteger index = round(self.crossPoint.x / (self.candleWidth + space));
        
        if (index >= 0 && index < self.visibleKLineData.count) {
            KLineModel *model = self.visibleKLineData[index];

            // 计算该蜡烛的中心 X 位置
            CGFloat candleCenterX = index * (self.candleWidth + space) + self.candleWidth / 2.0;
            CGFloat y = self.crossPoint.y;

            // 绘制虚线
            CGContextSetLineWidth(ctx, 0.5);
            CGContextSetStrokeColorWithColor(ctx, [UIColor grayColor].CGColor);
            CGFloat dashPattern[] = {4, 2};
            CGContextSetLineDash(ctx, 0, dashPattern, 2);

            // 横线
            CGContextMoveToPoint(ctx, 0, y);
            CGContextAddLineToPoint(ctx, self.bounds.size.width, y);
            CGContextStrokePath(ctx);

            // 纵线
            CGContextMoveToPoint(ctx, candleCenterX, 0);
            CGContextAddLineToPoint(ctx, candleCenterX, self.bounds.size.height);
            CGContextStrokePath(ctx);
            CGContextSetLineDash(ctx, 0, NULL, 0); // 关闭虚线

            // 长按显示：价格
            CGFloat priceRange = maxPrice - minPrice;
            CGFloat scale = viewHeight / priceRange;
            CGFloat price = maxPrice - y / scale;
            NSString *priceText = [NSString stringWithFormat:@"%.2f", price];
            NSDictionary *attr = @{NSFontAttributeName:[UIFont systemFontOfSize:18], NSForegroundColorAttributeName:[UIColor blackColor]};
            CGSize priceTextSize = [priceText sizeWithAttributes:attr];
            CGFloat leftX = self.contentOffsetX + 2; // 加2是为了内边距美观
            CGFloat priceTextY = y - priceTextSize.height / 2.0;
            [priceText drawAtPoint:CGPointMake(leftX, priceTextY) withAttributes:attr];

            // 长按显示：时间、成交量
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:model.timestamp];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *dateStr = [formatter stringFromDate:date];
            NSString *volumeStr = [NSString stringWithFormat:@"量: %.0f", model.volume];
            NSString *info = [NSString stringWithFormat:@"%@  %@", dateStr, volumeStr];
            CGSize textSize = [info sizeWithAttributes:attr];
            // 显示在成交量图下方（比 volume 区域再低一些）
            CGFloat textY = viewHeight - 18; // 比成交量底部低 5px
            CGFloat infoX = MIN(MAX(0, candleCenterX - textSize.width / 2), self.bounds.size.width - textSize.width);
            [info drawAtPoint:CGPointMake(infoX, textY) withAttributes:attr];
        }
    }
    
}

@end

@interface ViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) KLineChartView *chartView;
@property (nonatomic, strong) NSArray<KLineModel *> *allKLineData;//加载的全部json文件数据
@property (nonatomic, strong) NSMutableArray<KLineModel *> *loadedKLineData;//用于显示的300根-600根数据
@property (nonatomic, assign) NSInteger currentStartIndex;

@property (nonatomic, strong) NSMutableArray *holdPeriodList;//持仓时间数组
@property (nonatomic, assign) NSInteger maxHoldPeriod; // 记录最长持仓周期
@property (nonatomic,   copy) NSString *buyTime;//买入时间
@property (nonatomic,   copy) NSString *sallTime;//卖出时间
@property (nonatomic, assign) NSInteger winCount;//赢的次数
@property (nonatomic, assign) NSInteger lowerCount;//输的次数
@property (nonatomic, assign) double finalBalance;   // 最终资金
@property (nonatomic, assign) NSInteger tradeCount;  // 总交易数
@property (nonatomic, assign) NSInteger winTrades;   // 获利交易数
@property (nonatomic, strong) NSMutableArray<NSNumber *> *lossStreaks; // 连败统计数组 1~12
@property (nonatomic, strong) NSMutableArray<NSNumber *> *returnsArray;// 累计每一盘的盈亏
@property (nonatomic, assign) NSInteger currentLossStreak; // 当前连败数

@end

@implementation ViewController

- (NSMutableArray<NSNumber *> *)returnsArray {
    if (_returnsArray == nil) {
        _returnsArray = [NSMutableArray<NSNumber *> new];
    }
    return _returnsArray;
}

- (NSMutableArray<NSNumber *> *)lossStreaks {
    if (_lossStreaks == nil) {
        _lossStreaks = [NSMutableArray<NSNumber *> new];
    }
    return _lossStreaks;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    self.holdPeriodList = [NSMutableArray array];
    self.maxHoldPeriod = 0;
    self.buyTime = [NSString new];
    self.sallTime = [NSString new];
    self.finalBalance = 1.0;
    self.tradeCount = 0;
    self.winTrades = 0;
    self.currentLossStreak = 0;
    self.lossStreaks = [NSMutableArray array];
    for (int i = 0; i < 12; i++) {
        [self.lossStreaks addObject:@0];
    }

    
    CGFloat chartHeight = viewHeight + 10 + volumeHeight + 10 + rsiHeight;

    self.allKLineData = [self loadAllData];
    self.currentStartIndex = 0;
    self.loadedKLineData = [[self loadDataFromIndex:self.currentStartIndex count:MaxVisibleKLineCount] mutableCopy];
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];

    //计算 股票图的contentSize.width(可滑动的宽度)
    [self setupChartView:chartHeight];
    //计算RSI的模型数据
    [self calculateRSIWithPeriod:6];
    //计算BOLL的模型数据
    [self calculateBOLLWithPeriod:20];
    /*
     1.当RSI>80 且 k线的实体上穿布林线的蓝色线(bollUpper)时,等到出现k线下跌的第一根(开盘价大于收盘价),在K线的顶部标记橙色买入的字样
     2.当RSI<20 且 k线的实体下穿最底部布林线黑色(bollLower)时,等到出现k线上升的第一根(开盘价小于收盘价),在K线的顶部标记橙色买入的字样
     */
    [self detectRSI_BOLL_Signals];
    //打印结果
    [self printBacktestSummary];
}

- (void)printBacktestSummary {

    printf("============================\n");
    printf("===== 固定参数回测结果 =====\n");
    printf("============================\n");

    printf("最长持仓周期 = %ld 根K线\n", (long)self.maxHoldPeriod);
    NSLog(@"买入时间 = %@ \n", self.buyTime);
    NSLog(@"卖出时间 = %@ \n", self.sallTime);
    printf("TP = %.3f%%\n", TP_Parameter * 100);
    printf("SL = %.3f%%\n", SL_Parameter * 100);
    printf("最终资金乘数 = %.6f\n", self.finalBalance);
    printf("交易笔数 = %ld\n", (long)self.tradeCount);
    printf("获利笔数 = %ld\n", (long)self.winTrades);
    double winRate = 0.0;
    if (self.tradeCount > 0) {
        winRate = (double)self.winTrades / self.tradeCount * 100.0;
    }
    printf("胜率 = %.2f%%\n", winRate);
    double avgReturn = 0;
    if (self.returnsArray.count > 0) {
        double sum = 0;
        for (NSNumber *n in self.returnsArray) sum += n.doubleValue;
        avgReturn = sum / self.returnsArray.count;
    }
    printf("赢的次数 = %ld\n", (long)self.winCount);
    printf("输的次数 = %ld\n", (long)self.lowerCount);
    printf("平均每笔回报（%%） = %.4f%%\n", avgReturn);

    printf("========== 连败统计（1..12） ==========\n");
    for (int i = 0; i < 12; i++) {
        printf("连输%d: %d\n", i+1, self.lossStreaks[i].intValue);
    }
    
    printf("========== 持仓时间 ==========\n");
    for (int i = 0; i < self.holdPeriodList.count; i++) {
        NSNumber *num = self.holdPeriodList[i];
        printf("持仓时间%d 小时 \n", num.intValue);
    }
}


// 计算 RSI
- (void)calculateRSIWithPeriod:(NSInteger)n {
    if (self.allKLineData.count < n) return;

    CGFloat gainSum = 0, lossSum = 0;
    for (NSInteger i = 1; i <= n; i++) {
        CGFloat diff = self.allKLineData[i].close - self.allKLineData[i-1].close;
        if (diff >= 0) gainSum += diff;
        else lossSum += -diff;
    }
    CGFloat avgGain = gainSum / n;
    CGFloat avgLoss = lossSum / n;
    self.allKLineData[n].rsi = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain/avgLoss));

    for (NSInteger i = n+1; i < self.allKLineData.count; i++) {
        CGFloat diff = self.allKLineData[i].close - self.allKLineData[i-1].close;
        CGFloat gain = diff > 0 ? diff : 0;
        CGFloat loss = diff < 0 ? -diff : 0;

        avgGain = (avgGain * (n - 1) + gain) / n;
        avgLoss = (avgLoss * (n - 1) + loss) / n;

        self.allKLineData[i].rsi = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain/avgLoss));
    }
}

// 计算布林线：默认 N=20
- (void)calculateBOLLWithPeriod:(NSInteger)n {
    if (self.allKLineData.count < n) return;

    for (NSInteger i = n - 1; i < self.allKLineData.count; i++) {

        CGFloat sum = 0;
        for (NSInteger j = i - n + 1; j <= i; j++) {
            sum += self.allKLineData[j].close;
        }
        CGFloat ma = sum / n;

        // 计算标准差
        CGFloat variance = 0;
        for (NSInteger j = i - n + 1; j <= i; j++) {
            CGFloat diff = self.allKLineData[j].close - ma;
            variance += diff * diff;
        }
        CGFloat md = sqrt(variance / n);

        self.allKLineData[i].bollMiddle = ma;
        self.allKLineData[i].bollUpper = ma + 2 * md;
        self.allKLineData[i].bollLower = ma - 2 * md;
    }
}

/*
 做空（short）触发条件
 必须同时满足：
 1. RSI > 80
 2. 收盘价 > 开盘价（阳线，上涨 K 线）
 3. 收盘价 > 顶部布林线（向上站在布林线上方）
 📌 触发后不是立刻做空，而是等待 ➡ 等待出现第一根下跌 K 线（open > close）的下一根k线开盘价做空

 做空止盈止损
 止盈固定：-0.7%    即: 0.993(跌0.007)
 止损固定：+1%        即:1.01(升0.1)




 做多（long）触发条件
 必须同时满足：
 1. RSI < 20
 2. 收盘价 < 开盘价（阴线，下跌 K 线）
 3. 收盘价 < 底部布林线（向下站在布林线外）
 📌 触发后不是立刻做多，而是等待 ➡ 等待出现第一根上涨 K 线（open < close）的下一根k线开盘价做多

 做多止盈止损
 止盈固定：+0.7%    即:1.007(升0.07)
 止损固定：−1%       即:0.99(跌0.01)
 
 */
- (void)detectRSI_BOLL_Signals {

    BOOL inPosition = NO;
    NSInteger buyIndex = -1;
    CGFloat buyPrice = 0;
    NSString *direction = @"";
    
    BOOL waitForRise = NO;    // 等上涨确认 → 买升
    BOOL waitForDrop = NO;    // 等下跌确认 → 买跌

    self.winCount = 0;
    self.lowerCount = 0;

    for (NSInteger i = 1; i < self.allKLineData.count; i++) {

        KLineModel *m = self.allKLineData[i];

        // ==============================================================
        // ① 已持仓 → 检查卖出是否满足 TP / SL
        // ==============================================================
        if (inPosition) {

            BOOL closed = [self evaluateProfitFromIndex:i
                                               buyIndex:buyIndex
                                              buyPrice:buyPrice
                                              direction:direction];

            if (closed) {
                inPosition = NO;
                buyIndex = -1;
                buyPrice = 0;
            }

            continue;
        }

        // ==============================================================
        // ② 当前没有持仓 → 等待确认 K 线开仓
        // ==============================================================

        // ---- 等涨确认 → 买升（多单）----
        if (waitForRise) {

            if (m.close > m.open) {   // 必须是涨 K 才开仓（与 Python 一致）

                direction = @"long";
                buyIndex = i;
                buyPrice = m.close;    // 符合条件收盘价开仓

                m.signalTag = @"买升";
                inPosition = YES;

                waitForRise = NO;
                waitForDrop = NO;

                continue;
            }
        }

        // ---- 等跌确认 → 买跌（空单）----
        if (waitForDrop) {

            if (m.open > m.close) {   // 必须是跌 K 才开仓（与 Python 一致）

                direction = @"short";
                buyIndex = i;
                buyPrice = m.close; // 符合条件收盘价开仓

                m.signalTag = @"买跌";
                inPosition = YES;

                waitForDrop = NO;
                waitForRise = NO;

                continue;
            }
        }

        // ==============================================================
        // ③ 无仓位，也没有等待确认 → 检测信号本体
        // ==============================================================

        // ----------- RSI < 20 下穿下轨 → 下一根涨 K 才买升 -----------
        if (m.rsi < 20 &&
            m.close < m.open &&
            m.close < m.bollLower &&
            m.bollLower > 0.0) {

            waitForRise = YES;
            waitForDrop = NO;
            continue;
        }

        // ----------- RSI > 80 上穿上轨 → 下一根跌 K 才买跌 -----------
        if (m.rsi > 80 &&
            m.close > m.open &&
            m.close > m.bollUpper &&
            m.bollUpper > 0.0) {

            waitForDrop = YES;
            waitForRise = NO;
            continue;
        }
    }

}



// ============================================================
// 根据买点向后判断是否 赚 / 亏
// direction = @"down" 表示买跌
// direction = @"up"   表示买升
// ============================================================
- (BOOL)evaluateProfitFromIndex:(NSInteger)i
                       buyIndex:(NSInteger)buyIndex
                       buyPrice:(CGFloat)buyPrice
                      direction:(NSString *)direction {

    if (buyIndex < 0) return NO;

    // ===== 止盈止损百分比 =====
    CGFloat tpPct = TP_Parameter;    // 止盈
    CGFloat slPct = SL_Parameter;    // 止损

    CGFloat TP, SL;

    // ============================
    //   按多空方向计算目标价格
    // ============================
    if ([direction isEqualToString:@"long"]) {

        // 做多
        TP = buyPrice * (1 + tpPct);   // 上涨止盈
        SL = buyPrice * (1 - slPct);   // 下跌止损

    } else {

        // 做空
        TP = buyPrice * (1 - tpPct);   // 下跌止盈
        SL = buyPrice * (1 + slPct);   // 上涨止损
    }

    KLineModel *cur = self.allKLineData[i];

    // =====================
    //       做多逻辑
    // =====================
    if ([direction isEqualToString:@"long"]) {

        // --- 止盈（价格 >= TP）---
        if (cur.high >= TP) {
            NSInteger holdPeriod = i - buyIndex;
            [self.holdPeriodList addObject:@(holdPeriod)];
            if (holdPeriod > self.maxHoldPeriod) {
                self.maxHoldPeriod = holdPeriod;
                NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
                NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
                buy_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
                self.buyTime = buy_dateStr;
                NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
                NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
                sall_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
                self.sallTime = sall_dateStr;
            }
            
            
            self.winCount++;
            self.allKLineData[i].signalTag = @"赚";
            
            NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
            NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
            buy_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
            
            NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
            NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
            sall_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
                        
            NSLog(@"WIN 多单 | 买入时间: %@ | 卖出时间: %@ | 买: %.2f | 卖: %.2f | 盈利 %.2f%%",
                  buy_dateStr, sall_dateStr, buyPrice, TP, (TP-buyPrice)/buyPrice*100);
            
            // ======== 统计部分开始 ========
            // 总交易笔数
            self.tradeCount += 1;
            // 盈利笔数
            self.winTrades += 1;

            // 清零当前连败并记录到 streak 数组
            if (self.currentLossStreak > 0) {
                NSInteger idx = MIN(self.currentLossStreak - 1, 11);
                NSInteger old = self.lossStreaks[idx].integerValue;
                self.lossStreaks[idx] = @(old + 1);
                self.currentLossStreak = 0;
            }
            
            double pct = (TP - buyPrice) / buyPrice * 100.0;//单笔收益率(%) 赢一次固定 8%
            // === 复利计算（和 Python 完全一致）===
            double multiplier = 1.0 + pct / 100.0; //总金额的 1.08
            self.finalBalance *= multiplier;//总金额 * 1.08
            
            // 添加到数组（用于计算平均回报）
            [self.returnsArray addObject:@(pct)];
            // ======== 统计部分结束 ========


            return YES;
        }

        // --- 止损（价格 <= SL）---
        if (cur.low <= SL) {
            NSInteger holdPeriod = i - buyIndex;
            [self.holdPeriodList addObject:@(holdPeriod)];
            if (holdPeriod > self.maxHoldPeriod) {
                self.maxHoldPeriod = holdPeriod;
                NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
                NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
                buy_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
                self.buyTime = buy_dateStr;
                NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
                NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
                sall_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
                self.sallTime = sall_dateStr;
            }
            
            
            self.lowerCount++;
            self.allKLineData[i].signalTag = @"亏";
            
            NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
            NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
            buy_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
            
            NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
            NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
            sall_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
            
            NSLog(@"LOSE 多单 | 买入时间: %@ | 卖出时间: %@ | 买: %.2f | 卖: %.2f | 盈利 %.2f%%",
                  buy_dateStr, sall_dateStr, buyPrice, SL, (SL-buyPrice)/buyPrice*100);
            
            // ======== 统计部分开始 ========
            // 总交易笔数
            self.tradeCount += 1;
            // 总交易笔数
            self.currentLossStreak += 1;
            
            double pct = (SL -buyPrice) / buyPrice * 100.0;//单笔收益率(%)
            // === 复利计算（和 Python 完全一致）===
            double multiplier = 1.0 + pct / 100.0;
            self.finalBalance *= multiplier;
            // 添加到数组（用于计算平均回报）
            [self.returnsArray addObject:@(pct)];
            // ======== 统计部分结束 ========

            return YES;
        }
    }

    // =====================
    //       做空逻辑
    // =====================
    else {

        // --- 止盈（价格 <= TP）---
        if (cur.low <= TP) {
            NSInteger holdPeriod = i - buyIndex;
            [self.holdPeriodList addObject:@(holdPeriod)];
            if (holdPeriod > self.maxHoldPeriod) {
                self.maxHoldPeriod = holdPeriod;
                NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
                NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
                buy_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
                self.buyTime = buy_dateStr;
                NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
                NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
                sall_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
                self.sallTime = sall_dateStr;
            }
            
            
            self.winCount++;
            self.allKLineData[i].signalTag = @"赚";
            
            NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
            NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
            buy_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
            
            NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
            NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
            sall_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
            
            NSLog(@"WIN 空单 | 买入时间: %@ | 卖出时间: %@ | 卖空: %.2f | 平仓: %.2f | 盈利 %.2f%%",
                  buy_dateStr, sall_dateStr, buyPrice, TP, (buyPrice-TP)/buyPrice*100);
            
            // ======== 统计部分开始 ========
            // 总交易笔数
            self.tradeCount += 1;
            // 盈利笔数
            self.winTrades += 1;

            // 清零当前连败并记录到 streak 数组
            if (self.currentLossStreak > 0) {
                NSInteger idx = MIN(self.currentLossStreak - 1, 11);
                NSInteger old = self.lossStreaks[idx].integerValue;
                self.lossStreaks[idx] = @(old + 1);
                self.currentLossStreak = 0;
            }
            
            double pct = (buyPrice - TP) / buyPrice * 100.0;//单笔收益率(%)  8%
            // === 复利计算（和 Python 完全一致）===
            double multiplier = 1.0 + pct / 100.0;
            self.finalBalance *= multiplier;
            // 添加到数组（用于计算平均回报）
            [self.returnsArray addObject:@(pct)];
            // ======== 统计部分结束 ========

            return YES;
        }

        // --- 止损（价格 >= SL）---
        if (cur.high >= SL) {
            NSInteger holdPeriod = i - buyIndex;
            [self.holdPeriodList addObject:@(holdPeriod)];
            if (holdPeriod > self.maxHoldPeriod) {
                self.maxHoldPeriod = holdPeriod;
                NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
                NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
                buy_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
                self.buyTime = buy_dateStr;
                NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
                NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
                sall_formatter.dateFormat = @"yyyy-MM-dd HH";
                NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
                self.sallTime = sall_dateStr;
            }
            
            
            self.lowerCount++;
            self.allKLineData[i].signalTag = @"亏";
            
            NSDate *buy_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[buyIndex].timestamp];
            NSDateFormatter *buy_formatter = [[NSDateFormatter alloc] init];
            buy_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *buy_dateStr = [buy_formatter stringFromDate:buy_date];
            
            NSDate *sall_date = [NSDate dateWithTimeIntervalSince1970:self.allKLineData[i].timestamp];
            NSDateFormatter *sall_formatter = [[NSDateFormatter alloc] init];
            sall_formatter.dateFormat = @"yyyy-MM-dd HH";
            NSString *sall_dateStr = [sall_formatter stringFromDate:sall_date];
            
            NSLog(@"LOSE 空单 | 买入时间: %@ | 卖出时间: %@ | 卖空: %.2f | 平仓: %.2f | 盈利 %.2f%%",
                  buy_dateStr, sall_dateStr, buyPrice, SL, (buyPrice-SL)/buyPrice*100);
            
            // ======== 统计部分开始 ========
            // 总交易笔数
            self.tradeCount += 1;
            // 亏损笔数
            self.currentLossStreak += 1;
            
            double pct = (buyPrice - SL) / buyPrice * 100.0;//单笔收益率(%) -12
            // === 复利计算（和 Python 完全一致）===
            double multiplier = 1.0 + pct / 100.0;  //剩余总金额的 0.88 88%
            self.finalBalance *= multiplier;// 总金额 * 88%
            // 添加到数组（用于计算平均回报）
            [self.returnsArray addObject:@(pct)];
            // ======== 统计部分结束 ========

            
            return YES;
        }
    }

    return NO; // 继续持仓
}



//计算 股票图的contentSize.width(可滑动的宽度)
- (void)setupChartView:(CGFloat)chartHeight {
    CGFloat width = self.loadedKLineData.count * (8 + space);
    KLineChartView *chartView = [[KLineChartView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - chartHeight - SAFE_AREA_BOTTOM, width, chartHeight)];
    chartView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.2];
    chartView.visibleKLineData = self.loadedKLineData;

    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.scrollView addSubview:chartView];
    self.scrollView.contentSize = chartView.bounds.size;
    self.chartView = chartView;
}

//读取 全部的本地文件
- (NSArray<KLineModel *> *)loadAllData {
    NSMutableArray *result = [NSMutableArray array];
    NSArray *paths = [[NSBundle mainBundle] pathsForResourcesOfType:@"json" inDirectory:nil];
    NSArray *sortedPaths = [paths sortedArrayUsingComparator:^NSComparisonResult(NSString *p1, NSString *p2) {
        return [[p1 lastPathComponent] localizedStandardCompare:[p2 lastPathComponent]];
    }];

    for (NSString *filePath in sortedPaths) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        if (!data) continue;
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error) continue;
        NSArray *klineList = json[@"data"][@"kline_list"];
        for (NSDictionary *dict in klineList) {
            KLineModel *model = [[KLineModel alloc] init];
            model.open = [dict[@"open_price"] floatValue];
            model.high = [dict[@"high_price"] floatValue];
            model.low = [dict[@"low_price"] floatValue];
            model.close = [dict[@"close_price"] floatValue];
            model.timestamp = [dict[@"timestamp"] doubleValue];
            model.volume = [dict[@"volume"] floatValue];
            [result addObject:model];
        }
    }
    return result;
}

// 根据index 读取后面的300个模型数据
- (NSArray<KLineModel *> *)loadDataFromIndex:(NSInteger)start count:(NSInteger)count {
    if (start < 0) start = 0;
    NSInteger end = MIN(start + count, self.allKLineData.count);
    return [self.allKLineData subarrayWithRange:NSMakeRange(start, end - start)];
}

// 左右滑动执行
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.chartView.contentOffsetX = scrollView.contentOffset.x;
    
    CGFloat candleFullWidth = self.chartView.candleWidth + space;
    CGFloat maxOffsetX = self.loadedKLineData.count * candleFullWidth - SCREEN_WIDTH;

    // 向右滑到底部-把之前左边就的数据删除（数组最多存900个模型）
    if (scrollView.contentOffset.x >= maxOffsetX - 50) {
        NSInteger nextStart = self.currentStartIndex + MaxVisibleKLineCount;
        if (nextStart < self.allKLineData.count) {
            NSInteger nextCount = MIN(MaxVisibleKLineCount, self.allKLineData.count - nextStart);
            NSArray *newData = [self loadDataFromIndex:nextStart count:nextCount];

            [self.loadedKLineData addObjectsFromArray:newData];
            self.currentStartIndex = nextStart;

            // 删除左边多余的数据
            if (self.loadedKLineData.count > MaxCacheKLineCount) {
                NSInteger toRemove = self.loadedKLineData.count - MaxCacheKLineCount;
                NSRange removeRange = NSMakeRange(0, toRemove);
                [self.loadedKLineData removeObjectsInRange:removeRange];

                // 更新 scrollView.contentOffset 保持视觉不跳动
                scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x - toRemove * candleFullWidth, 0);
            }

            // 更新图表
            self.chartView.visibleKLineData = self.loadedKLineData;
            CGFloat newWidth = self.loadedKLineData.count * candleFullWidth;
            self.chartView.frame = CGRectMake(0, self.chartView.frame.origin.y, newWidth, self.chartView.frame.size.height);
            self.scrollView.contentSize = CGSizeMake(newWidth, self.scrollView.contentSize.height);
            [self.chartView setNeedsDisplay];
        }
    // 向左滑到底部-把之前右边就的数据删除（数组最多存900个模型）
    }else if (scrollView.contentOffset.x <= 50 && self.currentStartIndex > 0) {
        NSInteger prevCount = MaxVisibleKLineCount;
        NSInteger prevStart = MAX(self.currentStartIndex - prevCount, 0);
        NSArray *prevData = [self loadDataFromIndex:prevStart count:(self.currentStartIndex - prevStart)];
        
        if (prevData.count > 0) {
            [self.loadedKLineData insertObjects:prevData atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, prevData.count)]];
            self.currentStartIndex = prevStart;

            // 删除右边多余数据
            if (self.loadedKLineData.count > MaxCacheKLineCount) {
                NSInteger toRemove = self.loadedKLineData.count - MaxCacheKLineCount;
                NSRange removeRange = NSMakeRange(self.loadedKLineData.count - toRemove, toRemove);
                [self.loadedKLineData removeObjectsInRange:removeRange];
            }

            // 更新图表
            self.chartView.visibleKLineData = self.loadedKLineData;
            CGFloat newWidth = self.loadedKLineData.count * candleFullWidth;
            self.chartView.frame = CGRectMake(0, self.chartView.frame.origin.y, newWidth, self.chartView.frame.size.height);
            self.scrollView.contentSize = CGSizeMake(newWidth, self.scrollView.contentSize.height);

            // 向左插入后，调整 contentOffset 避免跳动
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x + prevData.count * candleFullWidth, 0);
            
            [self.chartView setNeedsDisplay];
        }
    }

}

@end


