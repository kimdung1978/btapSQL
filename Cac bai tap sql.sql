--Đề 1:
-- Cho sẵn dữ liệu như sau:
SET NOCOUNT ON;
IF OBJECT_ID('TempDb..#DMBP') IS NOT NULL DROP TABLE #DMBP;
CREATE TABLE #DMBP (Ma VARCHAR(16), Ten VARCHAR(32));

IF OBJECT_ID('TempDb..#DMNV') IS NOT NULL DROP TABLE #DMNV
CREATE TABLE #DMNV (Ma VARCHAR(16), Ten VARCHAR(32), Ma_Bp VARCHAR(16));

IF OBJECT_ID('TempDb..#ChungTu') IS NOT NULL DROP TABLE #ChungTu
CREATE TABLE #ChungTu (So_Ct VARCHAR(10), Dien_Giai VARCHAR(32), Ma_Nv VARCHAR(16), Tien NUMERIC(18,0));

DECLARE @_i NUMERIC(18,0), @_RandomMa INT, @_RandomValue NUMERIC(18,0),
		@_Ma_Bp VARCHAR(16), @_Ma_Nv VARCHAR(16)

SET @_i = 0
WHILE @_i <=9
BEGIN
	INSERT INTO #DMBP(Ma, Ten)
		VALUES('Ma_Bp' + CAST(@_i AS CHAR(2)), 'Ten bo phan ' + CAST(@_i AS CHAR(2)))

	SET @_RandomMa = RAND()*10
	IF @_RandomMa = 10 SET @_RandomMa = 0
	SET @_Ma_Bp = 'Ma_Bp' + CAST(@_RandomMa AS CHAR(1))

	INSERT INTO #DMNV(Ma, Ten, Ma_Bp)
		VALUES('Ma_Nv' + CAST(@_i AS CHAR(2)), 'Ten nhan vien ' + CAST(@_i AS CHAR(2)),@_Ma_Bp)

	SET @_i		= @_i + 1
END

SET @_i = 1
WHILE @_i <= 20
BEGIN
	SET @_RandomValue	= (RAND() * 1000 + RAND() * 1000 + RAND() * 1000)
	
	SET @_RandomMa = RAND()*10 
	IF @_RandomMa = 10 SET @_RandomMa = 0
	SET @_Ma_Nv = 'Ma_Nv' + CAST(@_RandomMa AS CHAR(1))

	INSERT INTO #ChungTu (So_Ct, Dien_Giai, Ma_Nv, Tien)
		VALUES ('So_Ct' + CAST(@_i AS VARCHAR(2)), 'Chung tu so: ' + CAST(@_i AS VARCHAR(2)), @_Ma_Nv, @_RandomValue)

	SET @_i = @_i + 1
END

/*-------------------------------------
 Bat buoc: Viết các phương án làm. Sau đó mới viết chương trình cho phương án đó
(Nếu không viết phương án coi như bài bị 0 điểm)
Có 2 câu hỏi sau: (Có thể làm câu nào trước cũng được)
-------------------------------------*/
-- Viết thủ tục cho 2 kết quả như sau
-- 1. Tổng doanh số bán hàng theo thứ tự giảm dần
-- So_Ct____________Ma_Nv_________Dien_Giai_________Tien
--__________________Ma_NV1____Ten nhan vien 1_______10000
--So_Ct1______________________Chung tu so: 1__________500 
--So_Ct3______________________Chung tu so: 3_________2000 
--So_Ct7______________________Chung tu so: 7_________7500 
--__________________Ma_NV3____Ten nhan vien 1________6000
--So_Ct2______________________Chung tu so: 2_________6000
--.......................................................
--_______________________________Tong cong__________22000

/*
PHƯƠNG ÁN : 
+ Tạo bảng Ma_Nv với sắp xếp số tiền giảm dần 
+ Mỗi Nhân viên sẽ có chứng từ khác nhau 
+ Có dòng tổng cộng ở cuối 
*/

DROP TABLE IF EXISTS #Temp1
SELECT ct.Ma_Nv, MAX(nv.Ten) Dien_Giai, SUM(Tien) Tien, ROW_NUMBER()OVER(ORDER BY SUM(Tien) DESC) stt1
INTO #Temp1
FROM #ChungTu ct
	LEFT OUTER JOIN #DMNV nv ON ct.Ma_Nv = nv.Ma
GROUP BY ct.Ma_Nv

SELECT '' So_Ct, Ma_Nv, Dien_Giai, Tien, 0 AS STT, stt1
FROM #Temp1
UNION ALL 
SELECT So_Ct, '', ct.Dien_Giai, ct.Tien, 0 AS STT, stt1 
FROM #ChungTu ct
	LEFT JOIN #Temp1 t ON t.Ma_Nv = ct.Ma_Nv
UNION ALL 
SELECT '', '', N'Tổng Cộng', SUM(Tien), 1, 0
FROM #ChungTu
ORDER BY STT, stt1, So_Ct

DROP TABLE #Temp1

-- 2. Tổng lợi nhuận của từng nhân viên, bộ phận (Doanh thu trừ chi phí) giảm dần. 
-- (Trong đó: Chi phí bộ phận được chia theo tỷ lệ doanh thu của từng bộ phận)
-- (Tổng chi phí từng BP được chia đều cho số lượng người trong bộ phận đó)
-- So_Ct____________Ma_________Dien_Giai___________Tien_DT__________Tien_CP_________Lai_Lo
--__________________Ma_BP1____Ten bo phan 1_________14000_____________8000___________6000 
--__________________Ma_NV1____Ten nhan vien 1_______10000_____________4000___________6000 
--So_Ct1______________________Chung tu so: 1__________500_______________________________0
--So_Ct3______________________Chung tu so: 3_________2000 ______________________________0 
--So_Ct7______________________Chung tu so: 7_________7500_______________________________0
--__________________Ma_NV2____Ten nhan vZien 2________4000_____________4000______________0
--So_Ct8______________________Chung tu so: 8_________4000_______________________________0
--__________________Ma_BP4______Ten bo phan 4________7000_____________4000___________3000
--__________________Ma_NV3____Ten nhan vien 1________6000_____________2000___________4000
--So_Ct2______________________Chung tu so: 2_________6000_______________________________0
--__________________Ma_NV7____Ten nhan vien 7________1000_____________2000__________-1000
--So_Ct8______________________Chung tu so: 8_________1000_____________2000__________-1000
--_______________________________Tong cong__________22000____________12000___________9000

/*
PHƯƠNG ÁN : 
+ Tạo bảng bộ phận , Tổng tiền chi phí * tiền doanh thu / tổng tiền doanh thu để lấy chi phí và sắp 
xếp theo giảm dần
+ Xử lý chênh lệch chi phí từng bộ phận 
+ Tạo bảng nhân viên, Lấy tiền chi phí bộ phận chia cho số nhân viên để lấy chi phí và sắp xếp theo
giảm dần.
+ Xử lý chênh lệch chi phí từng nhân viên
+ Lai_Lo = TienDT - TienCP và sắp xếp theo giảm dần
+ Có dòng tổng cộng ở cuối
*/

--Tạo bảng chung
DROP TABLE IF EXISTS #BangChung
SELECT ct.So_Ct, ct.Ma_Nv, nv.Ma_Bp, ct.Dien_Giai, ct.Tien, nv.Ten AS TenNv, bp.Ten AS TenBp
INTO #BangChung
FROM #ChungTu ct
	LEFT JOIN #DMNV nv ON ct.Ma_Nv = nv.Ma
	LEFT JOIN #DMBP bp ON bp.Ma = nv.Ma_Bp

--Tổng Chi phí
DECLARE @_Tien_CP NUMERIC(18, 0), @_TenDT NUMERIC(18,0), @_CL NUMERIC(18,0)
SET @_Tien_CP = ISNULL((SELECT SUM(Tien) FROM #ChungTu), 0) / (RAND() * 10)
SET @_TenDT = ISNULL((SELECT SUM(Tien) FROM #ChungTu), 0)

--bảng nhân viên
DROP TABLE IF EXISTS #Nv
SELECT MAX(Ma_Bp) Ma_Bp, Ma_Nv, MAX(TenNv) Dien_Giai, SUM(Tien) TienDT, 0 AS TienCP, 0 AS sx1 ,
	ROW_NUMBER()OVER(PARTITION BY MAX(Ma_Bp) ORDER BY SUM(Tien) DESC) sx2
INTO #Nv
FROM #BangChung
GROUP BY Ma_Nv

DROP TABLE IF EXISTS #Bp
SELECT Ma_Bp, Dien_Giai, TienDT, ROUND(@_Tien_CP * TienDT / @_TenDT,0) TienCP, sx1, SoNv 
INTO #Bp
FROM 
	(
		SELECT nv.Ma_Bp, MAX(ct.TenBp) Dien_Giai, SUM(nv.TienDT) TienDT, 0 AS TienCP, 0 AS sx1, COUNT(*) SoNv 
		FROM #Nv nv
			LEFT JOIN #BangChung ct ON nv.Ma_Bp = ct.Ma_Bp
		GROUP BY nv.Ma_Bp
	)nv

SET @_CL = @_Tien_CP - (SELECT SUM(TienCP) FROM #Bp)
IF @_Cl <> 0
	UPDATE TOP(1) #Bp SET TienCP += @_CL
	WHERE TienCP = (SELECT MAX(TienCP) FROM #Bp)

UPDATE #Bp SET sx1 = b2.sx1
FROM #Bp b1
	LEFT JOIN 
		(
			SELECT Ma_Bp, ROW_NUMBER()OVER(ORDER BY(TienDT-TienCP) DESC) sx1 
			FROM #Bp
		)b2 ON b1.Ma_Bp = b2.Ma_Bp

UPDATE #Nv SET TienCP = ROUND(bp.TienCP / bp.SoNv,0), sx1 = bp.sx1
FROM #Nv nv 
	LEFT JOIN #Bp bp On nv.Ma_Bp = bp.Ma_Bp

;WITH CLNV AS
(
	SELECT nv.Ma_Bp, bp.TienCP - nv.TienCP AS CL 
	FROM 
		(
			SELECT Ma_Bp, SUM(TienCP) TienCP 
			FROM #Nv
			GROUP BY Ma_Bp
		)nv
		LEFT JOIN #Bp bp On nv.Ma_Bp = bp.Ma_Bp
	WHERE (bp.TienCP - nv.TienCP) > 0
)
UPDATE #Nv SET TienCP +=CL
FROM #Nv nv
	LEFT JOIN CLNV nv1 ON nv.Ma_Bp = nv1.Ma_Bp
WHERE CL <> 0

SELECT '' So_Ct, Ma_Bp, Dien_Giai, TienDT, TienCP, TienDT - TienCP AS Lai_Lo, sx1 , 0 sx2 
FROM #Bp
UNION ALL 
SELECT '', Ma_Nv, Dien_Giai, TienDT, TienCP, TienDT - TienCP , sx1, sx2
FROM #Nv
UNION ALL
SELECT ct.So_Ct, '', ct.Dien_Giai, ct.Tien, 0, 0, nv.sx1, nv.sx2 
FROM #BangChung ct
	LEFT JOIN #Nv nv ON ct.Ma_Nv = nv.Ma_Nv
UNION ALL
SELECT '', '', N'Tổng Cộng', SUM(Tien), @_Tien_CP, SUM(Tien) - @_Tien_CP, 9999, 9999 
FROM #BangChung
ORDER BY sx1, sx2, So_Ct

DROP TABLE #BangChung, #Nv, #Bp

DROP TABLE #ChungTu, #DMBP, #DMNV

--ĐỀ 2:
SET NOCOUNT ON; 
IF OBJECT_ID('TempDb..#ChungTu1') IS NOT NULL DROP TABLE #ChungTu1
CREATE TABLE #ChungTu1 (So_Ct VARCHAR(10), Dien_Giai VARCHAR(32), Ma_Vt VARCHAR(16), Ma_Kho VARCHAR(16), So_Luong NUMERIC(18,0));

DECLARE @_i2 NUMERIC(18,0), @_RandomCode INT, @_RandomValue2 NUMERIC(18,0),
		@_Ma_Vt VARCHAR(16), @_Ma_Kho VARCHAR(16)

SET @_i2 = 1
WHILE @_i2 <= 20
BEGIN
	SET @_RandomValue2	= (RAND() * 1000 + RAND() * 1000 + RAND() * 1000)
	
	SET @_RandomCode = RAND()*10 
	IF @_RandomCode = 10 SET @_RandomCode = 0
	SET @_Ma_Vt = 'VT' + CAST(@_RandomCode AS CHAR(1))
	
	SET @_RandomCode = RAND()*10 
	IF @_RandomCode = 10 SET @_RandomCode = 0
	SET @_Ma_Kho = 'Kho' + CAST(@_RandomCode AS CHAR(1))

	INSERT INTO #ChungTu1 (So_Ct, Dien_Giai, Ma_Vt, Ma_Kho, So_Luong)
		VALUES ('So_' + CAST(@_i2 AS VARCHAR(2)), 'Chung tu so: ' + CAST(@_i2 AS VARCHAR(2)), @_Ma_Vt, @_Ma_Kho, @_RandomValue2)

	SET @_i2 = @_i2 + 1
END

--SELECT * FROM #ChungTu
-------------------------------------
/*
Yêu cầu dùng Pivot để làm bài sau đây:
1/ Tạo bảng dữ liệu như bên dưới:
	- Dựng thêm 4 cột phản ánh số lượng của mỗi chứng từ, trong đó 3 cột là của 3 kho có tổng số lượng lớn nhất, 1 cột còn lại của các kho khác
	- Thêm dòng Tổng cộng bên dưới
	- VD:(Tổng số lượng Kho8 > Kho3 > Kho4 > ...)
-------------------------------------------------------------------------------------------------------------------
So_Ct   |Dien_Giai            |Ma_Vt       |Ma_Kho      |So_Luong	|Kho8       |Kho3       |Kho4       |Kho_Khac         
So_018  |Chung tu so 18       |VT05        |Kho8		|19			|19         |0			|0			|0  
So_011  |Chung tu so 11       |VT02        |Kho4		|26			|0          |0			|26			|0  
So_004  |Chung tu so 4        |VT01        |Kho7		|12			|0          |0			|0			|12  
	...........
	...........
		|Tổng cộng										|1568		|500		|400		|300		|368
-------------------------------------------------------------------------------------------------------------------
*/

/*
PHƯƠNG PHÁP : 
+ Lấy 3 cột kho có tổng số lượng lớn nhất và 1 cột số lượng của các kho khác 
+ Dùng Pivot để hiển thị 4 cột phản ánh số lượng của mỗi chứng từ lên hàng ngang
+ Có 1 dòng tổng cộng ở cuối
*/
DECLARE @_Str VARCHAR(4000), @_List VARCHAR(1000), @_ListNull VARCHAR(1000), @_SLCot VARCHAR(16), @_CotKhac VARCHAR(16)
SELECT @_SLCot = 'SoLuong', @_CotKhac = 'Kho_Khac';

DROP TABLE IF EXISTS #Kho
SELECT TOP 3 Ma_Kho, ROW_NUMBER()OVER(ORDER BY SUM(So_Luong) DESC) stt 
INTO #Kho
FROM #ChungTu1
GROUP BY Ma_Kho

DROP TABLE IF EXISTS #Bai1
SELECT So_Ct, Dien_Giai, Ma_Vt, Ma_Kho, So_Luong, CASE WHEN Ma_Kho IN (SELECT Ma_Kho FROM #Kho) THEN Ma_Kho ELSE @_CotKhac END Ma_Kho1
INTO #Bai1
FROM #ChungTu1
UNION ALL 
SELECT So_Ct, Dien_Giai, Ma_Vt, Ma_Kho, So_Luong, @_SLCot AS Ma_Kho1 
FROM #ChungTu1

INSERT INTO #Bai1 (So_Ct, Dien_Giai, Ma_Vt, Ma_Kho, So_Luong, Ma_Kho1)
	SELECT '', 'Tong Cong', '', '', So_Luong, Ma_Kho1
	FROM #Bai1

INSERT INTO #Kho(Ma_Kho, stt)
	SELECT @_SLCot, 0
	UNION ALL
	SELECT @_CotKhac, 4

SET @_List = 
	(
		SELECT ',' + QUOTENAME(RTRIM(Ma_Kho)) 
		FROM #Kho
		ORDER BY stt
		FOR XML PATH('')
	)

SET @_ListNull = 
	(
		SELECT ',ISNULL(' + QUOTENAME(RTRIM(Ma_Kho)) + ',0) AS ' + QUOTENAME(RTRIM(Ma_Kho)) 
		FROM #Kho
		ORDER BY stt
		FOR XML PATH('')
	)

SET @_List = STUFF(@_List, 1, 1, '')
SET @_Str = 
	'
		SELECT So_Ct, Dien_Giai, Ma_Vt, Ma_Kho '+@_ListNull+' 
		FROM 
			(
				SELECT So_Ct, Dien_Giai, Ma_Vt, Ma_Kho, So_Luong, Ma_Kho1 
				FROM #Bai1
			)nv
		PIVOT 
			(
				SUM(So_Luong) FOR Ma_Kho1 IN ('+@_List+')
			)p
		ORDER BY CASE WHEN So_Ct = '''' THEN 1 ELSE 0 END, So_Ct
	'
EXEC(@_Str)

DROP TABLE #Kho, #Bai1

/*
2/ Tạo kết quả như bên dưới. Yêu cầu:
	- Nhóm các vật tư và kho theo hàng và cột để biết tổng phát sinh từng vật tư ở từng kho
	- Truyền tham số lựa chọn Vật tư hàng - Kho cột; hoặc Vật tư cột - Kho hàng
	Ví dụ: Vật tư hàng - Kho cột

Ma_Vt	|Kho1	|Kho2	|Kho3....	|KhoN
VT01	|19		|0		|35....		|12
VT02	|0		|20		|15...		|0
VT03	|18		|11		|0...		|20
......
Tổng	|82		|88		|102..		|99

--------------------------------------------------------------------------------------------------------------------------------------------------
- Lưu vào trong thư mục: \\bravohn\users\1e-TrienKhai\Thong_Bao\Test_Lap_Trinh\Lan8_Pivot
- Tên file lưu theo dạng: Lan8_[Phòng - Team]_[TênHọ nhân viên]
--> VD: Lan8_Team1_TruongPx, Lan8_BH_VuNh, Lan8_Test_HanhNt, ... (ai lưu sai sẽ bị trừ điểm)
----------------------------------------------------Bài làm---------------------------------------------------------------*/
DECLARE @_Loai VARCHAR(1), @_Ma_Dong VARCHAR(16), @_Ma_Cot VARCHAR(16)

SET @_Loai = '1';
IF @_Loai = '1'
	SELECT @_Ma_Dong = 'Ma_Vt', @_Ma_Cot = 'Ma_Kho'
ELSE
	SELECT @_Ma_Dong = 'Ma_Kho', @_Ma_Cot = 'Ma_Vt'

DROP TABLE IF EXISTS #DongCot
SELECT TOP 0 Ma_Vt AS Ma_Dong, Ma_Kho AS Ma_Cot, So_Luong 
INTO #DongCot
FROM #ChungTu1

SET @_Str = 
'
	INSERT INTO #DongCot (Ma_Dong, Ma_Cot, So_Luong)
		SELECT '+@_Ma_Dong+', '+@_Ma_Cot+', So_Luong 
		FROM #ChungTu1
'
EXEC (@_Str)

INSERT INTO #DongCot (Ma_Dong, Ma_Cot, So_Luong)
	SELECT 'Tong Cong', '', SUM(So_Luong) 
	FROM #DongCot

SET @_List = 
	(
		SELECT ',' + QUOTENAME(RTRIM(Ma_Cot)) 
		FROM #DongCot
		WHERE Ma_Cot <> ''
		GROUP BY Ma_Cot
		ORDER BY Ma_Cot
		FOR XML PATH('')
	)

SET @_ListNull = 
	(
		SELECT ',ISNULL(' + QUOTENAME(RTRIM(Ma_Cot)) + ',0) AS ' + QUOTENAME(RTRIM(Ma_Cot)) 
		FROM #DongCot
		WHERE Ma_Cot <> ''
		GROUP BY Ma_Cot
		ORDER BY Ma_Cot
		FOR XML PATH('')
	)

SET @_List = STUFF(@_List, 1, 1, '')
SET @_Str = 
	'SELECT Ma_Dong '+@_Ma_Dong+@_ListNull+'' + CHAR(13) +
	'FROM 
		(
			SELECT Ma_Dong, Ma_Cot, So_Luong 
			FROM #DongCot
		)nv' + CHAR(13) +
	'PIVOT 
			(
				SUM(So_Luong) FOR Ma_Cot IN ('+@_List+')
			)p
		ORDER BY CASE WHEN Ma_Dong = ''Tong Cong'' THEN 1 ELSE 0 END, Ma_Dong
	'
EXEC(@_Str)

DROP TABLE #DongCot

DROP TABLE #ChungTu1

--ĐỀ 3:
--Cho sẵn dữ liệu như sau:
SET NOCOUNT ON;
IF OBJECT_ID('TempDb..#DMBP') IS NOT NULL DROP TABLE #DMBP;
CREATE TABLE #DMBP (Code VARCHAR(16), Name VARCHAR(32));

IF OBJECT_ID('TempDb..#DMDT') IS NOT NULL DROP TABLE #DMDT
CREATE TABLE #DMDT (Code VARCHAR(16), Name VARCHAR(32));

IF OBJECT_ID('TempDb..#DMKM') IS NOT NULL DROP TABLE #DMKM
CREATE TABLE #DMKM (Code VARCHAR(16), Name VARCHAR(32));

IF OBJECT_ID('TempDb..#ChungTu') IS NOT NULL DROP TABLE #ChungTu
CREATE TABLE #ChungTu (So_Ct VARCHAR(10), Dien_Giai VARCHAR(32), Ma_Bp VARCHAR(16), Ma_Dt VARCHAR(16), Ma_Km VARCHAR(16), Tien NUMERIC(18,0));

DECLARE @_i1 NUMERIC(18,0), @_RandomCode1 INT, @_RandomValue1 NUMERIC(18,0),
		@_Ma_Bp1 VARCHAR(16), @_Ma_Dt VARCHAR(16), @_Ma_Km VARCHAR(16)

SET @_i1 = 0
WHILE @_i1 <=9
BEGIN

	INSERT INTO #DMBP(Code, Name)
		VALUES('Ma_Bp' + CAST(@_i1 AS CHAR(2)), 'Ten bo phan ' + CAST(@_i1 AS CHAR(2)))

	SET @_RandomCode1 = RAND()*10

	INSERT INTO #DMDT(Code, Name)
		VALUES('Ma_Dt' + CAST(@_i1 AS CHAR(2)), 'Ten doi tuong ' + CAST(@_i1 AS CHAR(2)))

	INSERT INTO #DMKM(Code, Name)
		VALUES('Ma_Km' + CAST(@_i1 AS CHAR(2)), 'Ten khoan muc ' + CAST(@_i1 AS CHAR(2)))

	SET @_i1		= @_i1 + 1
END

SET @_i1 = 1
WHILE @_i1 <= 20
BEGIN
	SET @_RandomValue1	= (RAND() * 1000 + RAND() * 1000 + RAND() * 1000)
	
	SET @_RandomCode1 = RAND()*10 
	IF @_RandomCode1 = 10 SET @_RandomCode1 = 0
	SET @_Ma_Bp1 = 'Ma_Bp' + CAST(@_RandomCode1 AS CHAR(1))
	
	SET @_RandomCode1 = RAND()*10 
	IF @_RandomCode1 = 10 SET @_RandomCode1 = 0
	SET @_Ma_Dt = 'Ma_Dt' + CAST(@_RandomCode1 AS CHAR(1))

	SET @_RandomCode1 = RAND()*10 
	IF @_RandomCode1 = 10 SET @_RandomCode1 = 0
	SET @_Ma_Km = 'Ma_Km' + CAST(@_RandomCode1 AS CHAR(1))


	INSERT INTO #ChungTu (So_Ct, Dien_Giai, Ma_Bp, Ma_Dt, Ma_Km, Tien)
		VALUES ('So_' + CAST(@_i1 AS VARCHAR(2)), 'Chung tu so: ' + CAST(@_i1 AS VARCHAR(2)), @_Ma_Bp1, @_Ma_Dt, @_Ma_Km, @_RandomValue1)

	SET @_i1 = @_i1 + 1
END

-------------------------------------
-- Viet chuong trinh de tu dong Nhom theo Ma_Bp hoac Ma_Dt (do lua chon truyen vao)
-- Dong chi tiet la cac chung tu
-- VD: Chon nhom theo Ma_Bp
-- So_Ct____________Dien_Giai_________Ma_Bp________Ma_Dt_________Ma_Km__________Tien
-- _______Ma_Bp1 - Ten bo phan 1______Ma_Bp1___________________________________10000
-- So_Ct1________Chung tu so 1_______Ma_Bp1_______Ma_Dt2______Ma_Km4___________4000
-- So_Ct5________Chung tu so 5_______Ma_Bp1_______Ma_Dt5______Ma_Km6___________6000
-- _______Ma_Bp2 - Ten bo phan 2______Ma_Bp1___________________________________20000
--...................................................................................
--______________Tong cong______________________________________________________30000
-- Luu file theo duong dan:Z:\1e-TrienKhai\Thong_Bao\Test_Lap_Trinh\Nhom_Co_Ban\
-- Cac bai lam xong luu theo dang: Group_By_TenNhanVien_PhongBan
-- VD Tuan Anh lam xong luu ten File: Group_By_NguyenTuanAnh_KT1

DECLARE @_Loai1 VARCHAR(1), @_Str1 VARCHAR(4000), @_Ma VARCHAR(16), @_Bang VARCHAR(16)

SET @_Loai1 = '1';
SET @_Ma = 
	CASE @_Loai1
		WHEN '1' THEN 'Ma_Bp'
		WHEN '2' THEN 'Ma_Dt'
		WHEN '3' THEN 'Ma_Km'
	END;

SET @_Bang = 
	CASE @_Loai1 
		WHEN '1' THEN '#DMBP'
		WHEN '2' THEN '#DMDT'
		WHEN '3' THEN '#DMKM'
	END;

SET @_Str1 = 
	'
		SELECT '''' So_Ct, CONCAT('+@_Ma+', '' - '', MAX(d.Name)) Dien_Giai, 
			IIF('+@_Loai1+' = ''1'', MAX(Ma_Bp), '''') Ma_Bp,
			IIF('+@_Loai1+' = ''2'', MAX(Ma_Dt), '''') Ma_Dt,
			IIF('+@_Loai1+' = ''3'', MAX(Ma_Km), '''') Ma_Km,
			SUM(Tien) Tien, 0 AS STT
		FROM #ChungTu ct
			LEFT JOIN '+@_Bang+' d ON ct.'+@_Ma+' = d.Code
		GROUP BY '+@_Ma+'
		UNION ALL
		SELECT So_Ct, Dien_Giai, Ma_Bp, Ma_Dt, Ma_Km, Tien, 0 AS STT
		FROM #ChungTu
		UNION ALL
		SELECT '''', ''Tong Cong'', '''', '''', '''', SUM(Tien), 1 AS STT
		FROM #ChungTu
		ORDER BY STT, '+@_Ma+', So_Ct
	'
EXEC(@_Str1)




