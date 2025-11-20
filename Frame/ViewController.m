

#import "ViewController.h"
#define viewHeight 300 // 蜡烛图高度
#define space 3 // 每条蜡烛图的间隙
#define MaxVisibleKLineCount 300 // 每次提取限制300个数据
#define MaxCacheKLineCount 600 // 数组限制最多600个可视数据
#define volumeHeight 80  // 成交量图形高度
#define rsiHeight 60 // RSI 指标高度

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

    //数组中开始的index
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    // 可视view显示的个数
    NSInteger countInView = ceil(SCREEN_WIDTH / (self.candleWidth + space)) + 1;
    NSInteger startIndex = MAX(0, self.contentOffsetX / (self.candleWidth + space));
    //可视数组中结束的index
    NSInteger endIndex = MIN(startIndex + countInView, self.visibleKLineData.count);

    // 局部最大最小价
    CGFloat maxPrice  = -MAXFLOAT;
    CGFloat minPrice  = MAXFLOAT;
    CGFloat maxVolume = -MAXFLOAT;
    CGFloat maxRSI = -MAXFLOAT;
    CGFloat minRSI = MAXFLOAT;

    for (NSInteger i = startIndex; i < endIndex; i++) {
        KLineModel *model = self.visibleKLineData[i];
        maxPrice = MAX(maxPrice, model.high);
        minPrice = MIN(minPrice, model.low);
        maxVolume = MAX(maxVolume, model.volume);
//        maxRSI = MAX(maxRSI, model.rsi);
//        minRSI = MIN(minRSI, model.rsi);
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
    CGFloat rsiScale = (maxRSI - minRSI) != 0 ? (rsiHeight / (maxRSI - minRSI)) : 1;

    
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
        
        // 绘制 成交量柱子
        CGFloat volHeight = model.volume * volumeScale;
        CGFloat volY = volumeTop + volumeHeight - volHeight;
        CGContextFillRect(ctx, CGRectMake(x, volY, self.candleWidth, volHeight));
        
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
    }
    
    // ========= 画布林线 =========
    CGContextSetLineWidth(ctx, 1.0);

    // 中轨线 (黄色)
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1 green:0.85 blue:0 alpha:1].CGColor);
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

    // 下轨线 (紫色)
    CGContextSetStrokeColorWithColor(ctx, [UIColor purpleColor].CGColor);
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
@property (nonatomic, strong) NSArray<KLineModel *> *allKLineData;
@property (nonatomic, strong) NSMutableArray<KLineModel *> *loadedKLineData;
@property (nonatomic, assign) NSInteger currentStartIndex;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    CGFloat chartHeight = viewHeight + 10 + volumeHeight + 10 + rsiHeight;

    self.allKLineData = [self loadAllData];
    [self calculateRSIWithPeriod:6];
    [self calculateBOLLWithPeriod:20];
    self.currentStartIndex = 0;
    self.loadedKLineData = [[self loadDataFromIndex:self.currentStartIndex count:MaxVisibleKLineCount] mutableCopy];
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];

    [self setupChartView:chartHeight];
    
    

    
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


- (void)setupChartView:(CGFloat)chartHeight {
    //计算临时显示view的总长度
    CGFloat width = self.loadedKLineData.count * (8 + space);
    KLineChartView *chartView = [[KLineChartView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - chartHeight - SAFE_AREA_BOTTOM, width, chartHeight)];
    chartView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.2];
    chartView.visibleKLineData = self.loadedKLineData;

    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.scrollView addSubview:chartView];
    self.scrollView.contentSize = chartView.bounds.size;
    self.chartView = chartView;
}

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

- (NSArray<KLineModel *> *)loadDataFromIndex:(NSInteger)start count:(NSInteger)count {
    if (start < 0) start = 0;
    NSInteger end = MIN(start + count, self.allKLineData.count);
    return [self.allKLineData subarrayWithRange:NSMakeRange(start, end - start)];
}

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





