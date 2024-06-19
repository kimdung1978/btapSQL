-- Tạo bảng tạm lưu trữ tồn đầu
DROP TABLE IF EXISTS #OpenWarehouse;
SELECT 
    WarehouseCode, 
    ItemCode, 
    Quantity AS OpenQuantity, 
    Amount AS OpenAmount 
INTO #OpenWarehouse
FROM OpenWarehouse;

-- Tạo bảng tạm lưu trữ phát sinh
DROP TABLE IF EXISTS #Ps_tmp;
SELECT 
    d.WarehouseCode, 
    dd.ItemCode, 
    d.DocDate, 
	d.Type,
    IIF(d.Type = 1, dd.Quantity, 0) AS SLNhap, 
    IIF(d.Type = 2, dd.Quantity, 0) AS SLXuat,
    IIF(d.Type = 1, dd.Amount, 0) AS TienNhap, 
    IIF(d.Type = 2, dd.Amount, 0) AS TienXuat
INTO #Ps_tmp
FROM Doc d
LEFT JOIN DocDetail dd ON d.DocId = dd.DocId
WHERE d.IsActive = 1;

-- Tạo bảng tạm kết hợp tồn đầu và phát sinh
DROP TABLE IF EXISTS #Ct0_tmp;
SELECT 
    WarehouseCode, 
    ItemCode, 
    0 AS SLNhap, 
    0 AS SLXuat, 
    0 AS TienNhap, 
    0 AS TienXuat,
    OpenQuantity, 
    OpenAmount,
	CAST(0 AS numeric(18,0)) TonCuoi ,
	CAST(0 AS numeric(18,0)) TienCuoi,
	CAST(NULL AS DATE) AS NgayXuat,
    CAST(0 AS numeric(18,0)) AS NgayChamLuanChuyen,
    CAST(0 AS numeric(18,0)) AS ThangChamLuanChuyen,
    CAST(0 AS numeric(18,0)) AS NamChamLuanChuyen
INTO #Ct0_tmp
FROM #OpenWarehouse;

-- Chèn dữ liệu phát sinh vào bảng tạm
INSERT INTO #Ct0_tmp (WarehouseCode, ItemCode, SLNhap, SLXuat, TienNhap, TienXuat, OpenQuantity ,OpenAmount, NgayChamLuanChuyen,
						ThangChamLuanChuyen, NamChamLuanChuyen, NgayXuat, TonCuoi, TienCuoi)
SELECT 
    WarehouseCode, 
    ItemCode, 
    SLNhap, 
    SLXuat, 
    TienNhap, 
    TienXuat,
	0,
	0,
	0,
	0,
	0,
	NULL,
	0,
	0
FROM #Ps_tmp;

--Ngày xuất gần nhất
UPDATE #Ct0_tmp SET NgayXuat = b.DocDate
FROM #Ct0_tmp ct
	OUTER APPLY
		(
			SELECT TOP(1) ItemCode, WarehouseCode, DocDate  
			FROM #Ps_tmp
			WHERE DocDate < GETDATE() AND Type = 2
			ORDER BY DocDate DESC
		)b
WHERE ct.ItemCode = b.ItemCode AND ct.WarehouseCode = b.WarehouseCode

UPDATE #Ct0_tmp SET TonCuoi = ISNULL(OpenQuantity + SLNhap - SLXuat,0) , TienCuoi = ISNULL(OpenAmount + TienNhap - TienXuat,0)

DELETE FROM #Ct0_tmp WHERE ABS(OpenQuantity) + ABS(SLNhap) - ABS(SLXuat) = 0 
	AND ABS(OpenAmount) + ABS(TienNhap) - ABS(TienXuat) = 0


UPDATE #Ct0_tmp SET NgayChamLuanChuyen = Ngay, ThangChamLuanChuyen = Thang, NamChamLuanChuyen = Nam
FROM #Ct0_tmp ct
	OUTER APPLY
		(
			SELECT TOP 1 ItemCode, DATEDIFF(DAY, DocDate, GETDATE()) Ngay, DATEDIFF (MONTH, DocDate, GETDATE()) Thang,
				DATEDIFF(YEAR, DocDate, GETDATE()) Nam
			FROM #Ps_tmp
			WHERE DocDate < GETDATE() AND Type = 2
			ORDER BY DocDate DESC
		)b 
WHERE b.ItemCode = ct.ItemCode

select * from #Ct0_tmp

DROP TABLE #OpenWarehouse, #Ps_tmp, #Ct0_tmp