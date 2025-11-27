-- =================================================================================================
-- SCRIPT DE CARGA MASIVA DE DATOS (DML) Y CREACIÓN DE VISTAS - VERSIÓN FINAL Y COMPROBADA
-- Objetivo: Asegurar que todos los inserts y vistas se ejecuten sin errores.
-- =================================================================================================

USE GymDB_Project;
GO

-- -------------------------------------------------------------------------------------------------
-- 1. CONFIGURACIÓN E INSERCIÓN DE DATOS ESTÁTICOS INICIALES
-- -------------------------------------------------------------------------------------------------

-- 1.1 LIMPIEZA INICIAL COMPLETA DE DATOS DE PRUEBA (Orden de dependencia inversa para evitar FK conflicts)
PRINT '--- 1.1 LIMPIEZA INICIAL COMPLETA DE DATOS DE PRUEBA ---';

-- 1. Limpiar Operaciones (depende de Member, Class)
DELETE FROM OperationsData.TB_Payment;
DELETE FROM OperationsData.TB_Enrollment;

-- 2. Limpiar Perfiles y Membresías (depende de Member)
DELETE FROM MemberData.TB_Membership;
DELETE FROM MemberData.TB_TrainerProfile;
DELETE FROM MemberData.TB_EmployeeProfile;

-- 3. Limpiar Miembros (depende de Gym)
DELETE FROM MemberData.TB_Member;

-- 4. Limpiar Equipamiento (depende de Class)
DELETE FROM GymCore.TB_Equipment;

-- 5. Limpiar Clases (depende de Gym)
DELETE FROM GymCore.TB_Class;

-- 6. Limpiar Gimnasios (si tienen IDs fijos)
DELETE FROM GymCore.TB_Gym WHERE GymId <= 4;
GO

-- 1.2 Inserción de Gimnasios Estáticos (4 Sedes)
PRINT '--- 1.2 INSERCIÓN DE GIMNASIOS ESTÁTICOS ---';
SET IDENTITY_INSERT GymCore.TB_Gym ON;
GO

INSERT INTO GymCore.TB_Gym (GymId, GymName, [Address], Phone, Email)
VALUES
(1, 'San Salvador Downtown Fitness', 'Alameda Roosevelt, San Salvador', '+503 2201-1001', 'ssdowntown@gym.com'),
(2, 'San Marcos Training Center', 'Boulevard San Marcos, San Marcos', '+503 2201-1002', 'sanmarcos@gym.com'),
(3, 'Santa Tecla Performance Club', 'Paseo El Carmen, Santa Tecla', '+503 2201-1003', 'santatecla@gym.com'),
(4, 'Soyapango Power Gym', 'Boulevard del Ejército, Soyapango', '+503 2201-1004', 'soyapango@gym.com');
GO

SET IDENTITY_INSERT GymCore.TB_Gym OFF;
GO

-- 1.3 Asignación de IDs y Inserción de Clases y Equipos
PRINT '--- 1.3 ASIGNACIÓN DE IDS, CLASES Y EQUIPOS ---';
DECLARE @GymId1 INT, @GymId2 INT, @GymId3 INT, @GymId4 INT;
SELECT @GymId1 = GymId FROM GymCore.TB_Gym WHERE GymName LIKE 'San Salvador%';
SELECT @GymId2 = GymId FROM GymCore.TB_Gym WHERE GymName LIKE 'San Marcos%';
SELECT @GymId3 = GymId FROM GymCore.TB_Gym WHERE GymName LIKE 'Santa Tecla%';
SELECT @GymId4 = GymId FROM GymCore.TB_Gym WHERE GymName LIKE 'Soyapango%';

-- Insertar Clases/Áreas (GymCore.TB_Class)
INSERT INTO GymCore.TB_Class (GymId, ClassName) VALUES
(@GymId1, 'Sala de Pesas'), (@GymId1, 'Estudio de Yoga'),
(@GymId2, 'Área Cardiovascular'), (@GymId2, 'Clases de Baile'),
(@GymId3, 'Piscina Olímpica'), (@GymId3, 'Boxeo'),
(@GymId4, 'Sala de Pesas'), (@GymId4, 'CrossFit Area');

-- Insertar Equipos (GymCore.TB_Equipment)
DECLARE @ClassPesas1 INT, @ClassCardio2 INT, @ClassPiscina3 INT, @ClassPesas4 INT;
SELECT @ClassPesas1 = ClassId FROM GymCore.TB_Class WHERE ClassName = 'Sala de Pesas' AND GymId = @GymId1;
SELECT @ClassCardio2 = ClassId FROM GymCore.TB_Class WHERE ClassName = 'Área Cardiovascular' AND GymId = @GymId2;
SELECT @ClassPiscina3 = ClassId FROM GymCore.TB_Class WHERE ClassName = 'Piscina Olímpica' AND GymId = @GymId3;
SELECT @ClassPesas4 = ClassId FROM GymCore.TB_Class WHERE ClassName = 'Sala de Pesas' AND GymId = @GymId4;

INSERT INTO GymCore.TB_Equipment (ClassId, EquipmentType, [Description], LastMaintenance) VALUES
(@ClassPesas1, 'Máquina de Remo', 'Equipo de entrenamiento de resistencia y cardio.', DATEADD(MONTH, -2, GETDATE())),
(@ClassCardio2, 'Bicicleta Estática', 'Equipo de cardio, bajo impacto.', DATEADD(DAY, -15, GETDATE())),
(@ClassPiscina3, 'Equipo de Flotación', 'Diversos equipos de seguridad para piscina.', DATEADD(YEAR, -1, GETDATE())),
(@ClassPesas4, 'Banca de Presa', 'Banca ajustable de alta resistencia.', GETDATE());
GO


-- -------------------------------------------------------------------------------------------------
-- 2. PROCEDIMIENTOS ALMACENADOS PARA CARGA MASIVA (8000+ INSERTS)
-- -------------------------------------------------------------------------------------------------

-- 2.1. SP para insertar 8000 miembros aleatorios (MemberData.TB_Member)
IF OBJECT_ID('dbo.SP_InsertRandomMembers', 'P') IS NOT NULL    DROP PROCEDURE dbo.SP_InsertRandomMembers;
GO

CREATE PROCEDURE dbo.SP_InsertRandomMembers
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @TotalMembers       INT = 8000,      -- total registros a insertar
        @TargetMembers      INT = 5000,      -- tipo Member
        @TargetTrainers     INT = 2000,      -- tipo Trainer
        @TargetEmployees    INT = 1000,      -- tipo Employee
        @CountMembers       INT = 0,
        @CountTrainers      INT = 0,
        @CountEmployees     INT = 0,
        @InsertedTotal      INT = 0,
        @GymCount           INT,
        @RandomGymId        INT,
        @MemberType         VARCHAR(15),
        @FirstName          VARCHAR(50),
        @LastName           VARCHAR(50),
        @BirthDate          DATE,
        @Phone              VARCHAR(20),
        @Email              VARCHAR(80),
        @StartDate          DATE,
        @EndDate            DATE,
        @DiffDays           INT,
        @FirstCount         INT,
        @LastCount          INT,
        @FirstIndex         INT,
        @LastIndex          INT;

    /* Contar gyms disponibles */
    SELECT @GymCount = COUNT(*) FROM GymCore.TB_Gym;

    IF @GymCount = 0
    BEGIN
        RAISERROR('No existen gyms en GymCore.TB_Gym. Inserta al menos uno antes de ejecutar este Procedimiento almacenado.', 16, 1);
        RETURN;
    END

    /* Tablas de nombres en memoria */
    DECLARE @FirstNames TABLE (Id INT IDENTITY(1,1), Name VARCHAR(50));
    DECLARE @LastNames  TABLE (Id INT IDENTITY(1,1), Name VARCHAR(50));

    INSERT INTO @FirstNames (Name)
    VALUES 
        ('Kevin'),('Luis'),('Carlos'),('Ana'),('María'),('Sofía'),
        ('Jorge'),('Daniel'),('Lucía'),('Elena'),('Andrés'),('Pablo'),
        ('Diego'),('Laura'),('Valeria'),('Ricardo'),('Miguel'),('Camila'),
        ('Javier'),('Fernando'),('Paola'),('Andrea'),('Isabel'),('Susana'),
        ('Gabriel'),('Mario'),('Rodrigo'),('Natalia'),('Bianca'),('Sergio');

    INSERT INTO @LastNames (Name)
    VALUES 
        ('Pacheco'),('García'),('López'),('Martínez'),('Hernández'),
        ('Ramírez'),('Flores'),('González'),('Pérez'),('Rodríguez'),
        ('Sánchez'),('Castro'),('Vargas'),('Rojas'),('Morales'),
        ('Navarro'),('Mendoza'),('Cruz'),('Ortiz'),('Reyes'),
        ('Silva'),('Ramos'),('Guerrero'),('Bautista'),('Suárez'),
        ('Campos'),('Chávez'),('Aguilar'),('Vega'),('Fuentes');

    SELECT @FirstCount = COUNT(*) FROM @FirstNames;
    SELECT @LastCount  = COUNT(*) FROM @LastNames;

    /* Rango de fechas de nacimiento */
    SET @StartDate = '1970-01-01';
    SET @EndDate   = '2005-12-31';
    SET @DiffDays  = DATEDIFF(DAY, @StartDate, @EndDate);

    /* Bucle principal hasta insertar los 8000 */
    WHILE @InsertedTotal < @TotalMembers
    BEGIN
        /* Decidir tipo según lo que falte */
        IF @CountMembers < @TargetMembers
            SET @MemberType = 'Member';
        ELSE IF @CountTrainers < @TargetTrainers
            SET @MemberType = 'Trainer';
        ELSE IF @CountEmployees < @TargetEmployees
            SET @MemberType = 'Employee';
        ELSE
            BREAK;

        /* Gym aleatorio */
        SELECT @RandomGymId = (SELECT TOP 1 GymId FROM GymCore.TB_Gym ORDER BY NEWID());

        /* Nombre y apellido aleatorios */
        SET @FirstIndex = (ABS(CHECKSUM(NEWID())) % @FirstCount) + 1;
        SET @LastIndex  = (ABS(CHECKSUM(NEWID())) % @LastCount) + 1;

        SELECT @FirstName = Name FROM @FirstNames WHERE Id = @FirstIndex;
        SELECT @LastName  = Name FROM @LastNames  WHERE Id = @LastIndex;

        /* Fecha de nacimiento aleatoria entre 1970-01-01 y 2005-12-31 */
        SET @BirthDate = DATEADD(DAY, (ABS(CHECKSUM(NEWID())) % (@DiffDays + 1)), @StartDate);

        /* Teléfono random (formato simple) */
        SET @Phone = CONCAT('7', RIGHT(ABS(CHECKSUM(NEWID())) % 10000000 + 1000000, 7));

        /* Email random basado en nombre + contador total para evitar repetidos */
        SET @Email = LOWER(
                        CONCAT(
                            REPLACE(@FirstName, ' ', ''),
                            '.',
                            REPLACE(@LastName, ' ', ''),
                            @InsertedTotal + 1,
                            '@gymdata.com'
                        )
                     );
        
        INSERT INTO MemberData.TB_Member (
            GymId, MemberType, FirstName, LastName, BirthDate, Phone, Email
        )
        VALUES (
            @RandomGymId, @MemberType, @FirstName, @LastName, @BirthDate, @Phone, @Email
        );

        /* Actualizar contadores */
        SET @InsertedTotal += 1;

        IF @MemberType = 'Member'
            SET @CountMembers += 1;
        ELSE IF @MemberType = 'Trainer'
            SET @CountTrainers += 1;
        ELSE IF @MemberType = 'Employee'
            SET @CountEmployees += 1;
    END

    PRINT CONCAT('Insertados Miembros Totales: ', @InsertedTotal);
END
GO

-- 2.2. SP: Asignar Membresía (TB_Membership) a miembros tipo 'Member'
IF OBJECT_ID('dbo.SP_FillMembership', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_FillMembership;
GO

CREATE PROCEDURE dbo.SP_FillMembership
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MemberId INT, @MembershipType VARCHAR(20), @StartDate DATE, @EndDate DATE, @DaysBack INT, @ExtraDays INT, @RandMem INT;
    
    DECLARE CurMembers CURSOR FAST_FORWARD FOR
        SELECT M.MemberId
        FROM MemberData.TB_Member AS M
        LEFT JOIN MemberData.TB_Membership AS T ON T.MemberId = M.MemberId
        WHERE M.MemberType = 'Member' AND T.MemberId IS NULL;

    OPEN CurMembers;
    FETCH NEXT FROM CurMembers INTO @MemberId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DaysBack = ABS(CHECKSUM(NEWID())) % (365 * 3);
        SET @StartDate = DATEADD(DAY, -@DaysBack, CAST(GETDATE() AS DATE));
        SET @ExtraDays = (ABS(CHECKSUM(NEWID())) % 365) + 1;
        SET @EndDate = DATEADD(DAY, @ExtraDays, @StartDate);
        SET @RandMem = (ABS(CHECKSUM(NEWID())) % 3) + 1;

        SET @MembershipType = CASE @RandMem
                                  WHEN 1 THEN 'Silver' WHEN 2 THEN 'Gold' ELSE 'Diamond' END;

        INSERT INTO MemberData.TB_Membership (MemberId, MembershipType, StartDate, EndDate)
        VALUES (@MemberId, @MembershipType, @StartDate, @EndDate);

        FETCH NEXT FROM CurMembers INTO @MemberId;
    END

    CLOSE CurMembers;
    DEALLOCATE CurMembers;
    PRINT 'Insertadas Membresías (TB_Membership).';
END
GO

-- 2.3. SP: Asignar Perfil a Entrenadores (TB_TrainerProfile)
IF OBJECT_ID('dbo.SP_FillTrainerProfile', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_FillTrainerProfile;
GO

CREATE PROCEDURE dbo.SP_FillTrainerProfile
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MemberId INT, @Specialty VARCHAR(30), @StartDate DATE, @EndDate DATE, @DaysBack INT, @ExtraDays INT, @RandTrainer INT;

    DECLARE CurTrainers CURSOR FAST_FORWARD FOR
        SELECT M.MemberId
        FROM MemberData.TB_Member AS M
        LEFT JOIN MemberData.TB_TrainerProfile AS T ON T.MemberId = M.MemberId
        WHERE M.MemberType = 'Trainer' AND T.MemberId IS NULL;

    OPEN CurTrainers;
    FETCH NEXT FROM CurTrainers INTO @MemberId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DaysBack = ABS(CHECKSUM(NEWID())) % (365 * 3);
        SET @StartDate = DATEADD(DAY, -@DaysBack, CAST(GETDATE() AS DATE));
        SET @ExtraDays = (ABS(CHECKSUM(NEWID())) % 365) + 1;
        SET @EndDate = DATEADD(DAY, @ExtraDays, @StartDate);
        SET @RandTrainer = (ABS(CHECKSUM(NEWID())) % 3) + 1;

        SET @Specialty = CASE @RandTrainer
                             WHEN 1 THEN 'Zumba & Yoga' WHEN 2 THEN 'General Fitness' ELSE 'Athletic' END;

        INSERT INTO MemberData.TB_TrainerProfile (MemberId, Specialty, StartDate, EndDate)
        VALUES (@MemberId, @Specialty, @StartDate, @EndDate);

        FETCH NEXT FROM CurTrainers INTO @MemberId;
    END

    CLOSE CurTrainers;
    DEALLOCATE CurTrainers;
    PRINT 'Insertados Perfiles de Entrenadores (TB_TrainerProfile).';
END
GO

-- 2.4. SP: Asignar Perfil a Empleados (TB_EmployeeProfile)
IF OBJECT_ID('dbo.SP_FillEmployeeProfile', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_FillEmployeeProfile;
GO

CREATE PROCEDURE dbo.SP_FillEmployeeProfile
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MemberId INT, @ServiceType VARCHAR(20), @StartDate DATE, @EndDate DATE, @DaysBack INT, @ExtraDays INT, @RandEmp INT;

    DECLARE CurEmployees CURSOR FAST_FORWARD FOR
        SELECT M.MemberId
        FROM MemberData.TB_Member AS M
        LEFT JOIN MemberData.TB_EmployeeProfile AS E ON E.MemberId = M.MemberId
        WHERE M.MemberType = 'Employee' AND E.MemberId IS NULL;

    OPEN CurEmployees;
    FETCH NEXT FROM CurEmployees INTO @MemberId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DaysBack = ABS(CHECKSUM(NEWID())) % (365 * 3);
        SET @StartDate = DATEADD(DAY, -@DaysBack, CAST(GETDATE() AS DATE));
        SET @ExtraDays = (ABS(CHECKSUM(NEWID())) % 365) + 1;
        SET @EndDate = DATEADD(DAY, @ExtraDays, @StartDate);
        SET @RandEmp = (ABS(CHECKSUM(NEWID())) % 3) + 1;

        SET @ServiceType = CASE @RandEmp
                               WHEN 1 THEN 'Cleaning' WHEN 2 THEN 'Maintenance' ELSE 'Administration' END;

        INSERT INTO MemberData.TB_EmployeeProfile (MemberId, ServiceType, StartDate, EndDate)
        VALUES (@MemberId, @ServiceType, @StartDate, @EndDate);

        FETCH NEXT FROM CurEmployees INTO @MemberId;
    END

    CLOSE CurEmployees;
    DEALLOCATE CurEmployees;
    PRINT 'Insertados Perfiles de Empleados (TB_EmployeeProfile).';
END
GO

-- 2.5. SP: Asignar Inscripciones aleatorias (OperationsData.TB_Enrollment)
IF OBJECT_ID('dbo.SP_FillRandomEnrollments', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_FillRandomEnrollments;
GO

CREATE PROCEDURE dbo.SP_FillRandomEnrollments
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MemberId INT, @ClassId INT, @ClassCount INT;

    SELECT @ClassCount = COUNT(*) FROM GymCore.TB_Class;
    
    DECLARE CurMembers CURSOR FAST_FORWARD FOR
        SELECT MemberId FROM MemberData.TB_Member WHERE MemberType = 'Member';

    OPEN CurMembers;
    FETCH NEXT FROM CurMembers INTO @MemberId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Seleccionar una clase aleatoria
        SELECT TOP 1 @ClassId = ClassId FROM GymCore.TB_Class ORDER BY NEWID();

        -- Insertar inscripción
        INSERT INTO OperationsData.TB_Enrollment (MemberId, ClassId, EnrollmentDate)
        VALUES (@MemberId, @ClassId, DATEADD(DAY, - (ABS(CHECKSUM(NEWID())) % 365), GETDATE()));
        
        FETCH NEXT FROM CurMembers INTO @MemberId;
    END

    CLOSE CurMembers;
    DEALLOCATE CurMembers;
    PRINT 'Insertadas Inscripciones aleatorias (TB_Enrollment).';
END
GO

-- 2.6. SP: Asignar Pagos aleatorios (OperationsData.TB_Payment)
IF OBJECT_ID('dbo.SP_FillRandomPayments', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_FillRandomPayments;
GO

CREATE PROCEDURE dbo.SP_FillRandomPayments
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MemberId INT, @PaymentCount INT = 0;
    DECLARE @MinMemberId INT, @MaxMemberId INT;
    DECLARE @NumPayments INT, @PaymentMethod VARCHAR(20), @Amount DECIMAL(10, 2);

    -- Determinar el rango de IDs de miembros regulares
    SELECT @MinMemberId = MIN(MemberId), @MaxMemberId = MAX(MemberId) FROM MemberData.TB_Member WHERE MemberType = 'Member';
    
    WHILE @MinMemberId <= @MaxMemberId
    BEGIN
        IF EXISTS (SELECT 1 FROM MemberData.TB_Member WHERE MemberId = @MinMemberId AND MemberType = 'Member')
        BEGIN
            -- Generar entre 1 y 3 pagos por miembro
            SET @NumPayments = (ABS(CHECKSUM(NEWID())) % 3) + 1; 

            DECLARE @i INT = 1;
            WHILE @i <= @NumPayments
            BEGIN
                -- Método de pago aleatorio
                SET @PaymentMethod = CASE (ABS(CHECKSUM(NEWID())) % 3) + 1 
                                     WHEN 1 THEN 'Credit Card' 
                                     WHEN 2 THEN 'Debit Card' 
                                     ELSE 'Cash' END;

                -- Monto aleatorio entre 15.00 y 50.00
                SET @Amount = (ABS(CHECKSUM(NEWID())) % 36) + 15.00; 

                -- Fecha de pago aleatoria en los últimos 12 meses
                INSERT INTO OperationsData.TB_Payment (MemberId, Amount, PaymentDescription, PaymentMethod, PaymentDate)
                VALUES (@MinMemberId, @Amount, 'Monthly Fee', @PaymentMethod, DATEADD(DAY, - (ABS(CHECKSUM(NEWID())) % 365), GETDATE()));
                
                SET @PaymentCount = @PaymentCount + 1;
                SET @i = @i + 1;
            END
        END
        SET @MinMemberId = @MinMemberId + 1;
    END

    PRINT CONCAT('Insertados ', @PaymentCount, ' Pagos aleatorios (TB_Payment).');
END
GO

-- -------------------------------------------------------------------------------------------------
-- 3. EJECUCIÓN DE LA CARGA MASIVA
-- -------------------------------------------------------------------------------------------------

PRINT '--- 3. EJECUCIÓN DE LA CARGA MASIVA (8000+ REGISTROS) ---';

-- 3.1. Cargar 8000 Miembros
EXEC dbo.SP_InsertRandomMembers;
GO

-- 3.2. Asignar Perfiles a los 8000 Miembros
EXEC dbo.SP_FillMembership;
EXEC dbo.SP_FillTrainerProfile;
EXEC dbo.SP_FillEmployeeProfile;
GO

-- 3.3. Asignar Operaciones (Enrollment y Pagos)
EXEC dbo.SP_FillRandomEnrollments;
EXEC dbo.SP_FillRandomPayments;
GO

-- -------------------------------------------------------------------------------------------------
-- 4. CREACIÓN DE VISTAS DE NEGOCIO (VIEW)
-- -------------------------------------------------------------------------------------------------

PRINT '--- 4. CREACIÓN DE VISTAS DE NEGOCIO ---';

-- 4.1. Vista: VW_MiembrosActivosDetalle (Filtra solo miembros activos con su plan y gimnasio)
IF OBJECT_ID('dbo.VW_MiembrosActivosDetalle','V') IS NOT NULL DROP VIEW dbo.VW_MiembrosActivosDetalle;
GO
CREATE VIEW dbo.VW_MiembrosActivosDetalle
AS
SELECT
    M.MemberId,
    M.FirstName + ' ' + M.LastName AS NombreCompleto,
    G.GymName AS Sede,
    MS.MembershipType AS TipoMembresia,
    MS.StartDate AS FechaInicio,
    MS.EndDate AS FechaFin,
    MS.IsActive AS Vigente
FROM MemberData.TB_Member M
INNER JOIN MemberData.TB_Membership MS ON M.MemberId = MS.MemberId
INNER JOIN GymCore.TB_Gym G ON M.GymId = G.GymId
WHERE M.MemberType = 'Member' AND MS.IsActive = 1;
GO

-- 4.2. Vista: VW_HistoricoPagosResumen (Resumen de transacciones con método de pago)
IF OBJECT_ID('dbo.VW_HistoricoPagosResumen','V') IS NOT NULL DROP VIEW dbo.VW_HistoricoPagosResumen;
GO
CREATE VIEW dbo.VW_HistoricoPagosResumen
AS
SELECT
    P.PaymentId,
    M.MemberId,
    M.FirstName + ' ' + M.LastName AS Miembro,
    P.Amount AS Monto,
    P.PaymentMethod AS Metodo,
    P.PaymentDate AS FechaPago,
    G.GymName AS Sede
FROM OperationsData.TB_Payment P
INNER JOIN MemberData.TB_Member M ON P.MemberId = M.MemberId
INNER JOIN GymCore.TB_Gym G ON M.GymId = G.GymId;
GO