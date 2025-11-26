-- ================================================================================================================================
-- PROYECTO FINAL: GymDB_Project
-- AUTOR: Rene Antonio Vasquez Torres - 00122224. Bryan Gabriel Alfaro Canizalez - 00221324. Kevin Daniel Rosa Pacheco - 00210024.
-- ================================================================================================================================

USE master;
GO

---------------------------------------------------------------------------------------------------
-- FASE 1: PREPARACIÓN Y DIMENSIONAMIENTO
---------------------------------------------------------------------------------------------------

-- 1. DETENER Y ELIMINAR LA BASE DE DATOS PREVIA (si existe)
IF EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE name = N'GymDB_Project')
BEGIN
    ALTER DATABASE GymDB_Project SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GymDB_Project;
END
GO

-- 2. CREACIÓN DE LA BASE DE DATOS CON DIMENSIONAMIENTO
CREATE DATABASE GymDB_Project
ON
( NAME = GymDB_Data,
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\GymDB_Data.mdf', -- AJUSTA LA RUTA SI ES NECESARIO
    SIZE = 200MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 50MB )
LOG ON
( NAME = GymDB_Log,
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\GymDB_Log.ldf', -- AJUSTA LA RUTA SI ES NECESARIO
    SIZE = 50MB,
    MAXSIZE = 1GB,
    FILEGROWTH = 10% );
GO

-- 3. SELECCIÓN DE LA BASE DE DATOS
USE GymDB_Project;
GO

-- 4. CREACIÓN DE ESQUEMAS (CRITERIO: Organización Lógica / Seguridad)
CREATE SCHEMA GymCore;
GO
CREATE SCHEMA MemberData;
GO
CREATE SCHEMA OperationsData;
GO

---------------------------------------------------------------------------------------------------
-- FASE 2: DEFINICIÓN DE TABLAS Y CONSTRAINTS (DDL)
---------------------------------------------------------------------------------------------------

-- 5.1. dbo.TB_AuditLog (Tabla central para los Triggers)

CREATE TABLE dbo.TB_AuditLog
(
	TableName VARCHAR(50) NOT NULL,
	ActionType VARCHAR(50) NOT NULL,
	UserName VARCHAR(50) NOT NULL,
	AuditDate DATETIME NOT NULL
);
GO

-- 5.2. GymCore.TB_Gym (Gimnasios/Sedes)

CREATE TABLE GymCore.TB_Gym (
    GymId INT IDENTITY(1,1) PRIMARY KEY,
    GymName VARCHAR(100) NOT NULL UNIQUE,
    [Address] VARCHAR(255),
    Phone VARCHAR(20),
    Email VARCHAR(80)
);
GO

-- 5.3. MemberData.TB_Member (Tabla Maestra de Personas)

CREATE TABLE MemberData.TB_Member (
    MemberId INT IDENTITY(1000,1) PRIMARY KEY,
    GymId INT NOT NULL,
    MemberType VARCHAR(15) NOT NULL, 
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    BirthDate DATE,
    Phone VARCHAR(20),
    Email VARCHAR(80) UNIQUE,
    CONSTRAINT CK_Member_Type CHECK (MemberType IN ('Member', 'Trainer', 'Employee')),
    CONSTRAINT FK_Member_Gym FOREIGN KEY (GymId)
        REFERENCES GymCore.TB_Gym (GymId)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
);
GO

-- 5.4. MemberData.TB_Membership (Perfiles de Miembros Regulares)

CREATE TABLE MemberData.TB_Membership (
    MembershipId INT IDENTITY(1,1) PRIMARY KEY,
    MemberId INT NOT NULL UNIQUE, -- Relación 1:1
    MembershipType VARCHAR(20) NOT NULL,
    StartDate DATE NOT NULL DEFAULT GETDATE(),
    EndDate DATE,
    IsActive AS CAST(CASE WHEN EndDate >= GETDATE() THEN 1 ELSE 0 END AS BIT),
    CONSTRAINT CK_Membership_Type CHECK (MembershipType IN ('Silver', 'Gold', 'Diamond')),
    CONSTRAINT FK_Membership_Member FOREIGN KEY (MemberId)
        REFERENCES MemberData.TB_Member (MemberId)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
GO

-- 5.5. MemberData.TB_TrainerProfile (Perfiles de Entrenadores)

CREATE TABLE MemberData.TB_TrainerProfile (
    TrainerProfileId INT IDENTITY(1,1) PRIMARY KEY,
    MemberId INT NOT NULL UNIQUE, -- Relación 1:1
    Specialty VARCHAR(50) NOT NULL,
    StartDate DATE NOT NULL DEFAULT GETDATE(),
    EndDate DATE,
    CONSTRAINT CK_Trainer_Specialty CHECK (Specialty IN ('Zumba & Yoga', 'General Fitness', 'Athletic')),
    CONSTRAINT FK_Trainer_Member FOREIGN KEY (MemberId)
        REFERENCES MemberData.TB_Member (MemberId)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
GO

-- 5.6. MemberData.TB_EmployeeProfile (Perfiles de Empleados Administrativos/Servicio)

CREATE TABLE MemberData.TB_EmployeeProfile (
    EmployeeProfileId INT IDENTITY(1,1) PRIMARY KEY,
    MemberId INT NOT NULL UNIQUE, -- Relación 1:1
    ServiceType VARCHAR(50) NOT NULL,
    StartDate DATE NOT NULL DEFAULT GETDATE(),
    EndDate DATE,
    CONSTRAINT CK_Employee_ServiceType CHECK (ServiceType IN ('Cleaning', 'Maintenance', 'Administration')),
    CONSTRAINT FK_Employee_Member FOREIGN KEY (MemberId)
        REFERENCES MemberData.TB_Member (MemberId)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
GO

-- 6.1. GymCore.TB_Class (Clases o Áreas de Entrenamiento)

CREATE TABLE GymCore.TB_Class (
    ClassId INT IDENTITY(1,1) PRIMARY KEY,
    GymId INT NOT NULL,
    ClassName VARCHAR(100) NOT NULL,
    CONSTRAINT FK_Class_Gym FOREIGN KEY (GymId)
        REFERENCES GymCore.TB_Gym (GymId)
        ON DELETE CASCADE
);
GO

-- 6.2. GymCore.TB_Equipment (Inventario de Equipos)

CREATE TABLE GymCore.TB_Equipment (
    EquipmentId INT IDENTITY(1,1) PRIMARY KEY,
    ClassId INT NOT NULL,
    EquipmentType VARCHAR(100) NOT NULL,
    [Description] VARCHAR(300),
    LastMaintenance DATETIME,
    CONSTRAINT FK_Equipment_Class FOREIGN KEY (ClassId)
        REFERENCES GymCore.TB_Class (ClassId)
        ON DELETE CASCADE
);
GO

-- 6.3. OperationsData.TB_Enrollment (Inscripciones de Miembros a Clases)

CREATE TABLE OperationsData.TB_Enrollment (
    EnrollmentId INT IDENTITY(1,1) PRIMARY KEY,
    MemberId INT NOT NULL,
    ClassId INT NOT NULL,
    EnrollmentDate DATE NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UK_Enrollment UNIQUE (MemberId, ClassId),
    CONSTRAINT FK_Enrollment_Member FOREIGN KEY (MemberId)
        REFERENCES MemberData.TB_Member (MemberId)
        ON DELETE CASCADE,
    CONSTRAINT FK_Enrollment_Class FOREIGN KEY (ClassId)
        REFERENCES GymCore.TB_Class (ClassId)
        ON DELETE NO ACTION
);
GO

-- 6.4. OperationsData.TB_Payment (Historial de Pagos)

CREATE TABLE OperationsData.TB_Payment (
    PaymentId INT IDENTITY(1,1) PRIMARY KEY,
    MemberId INT NOT NULL,
    Amount DECIMAL(10,2) NOT NULL,
    PaymentDescription VARCHAR(150),
    PaymentMethod VARCHAR(20),
    PaymentDate DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Payment_Member FOREIGN KEY (MemberId)
        REFERENCES MemberData.TB_Member (MemberId)
        ON DELETE NO ACTION
);
GO

-- 6.5. OperationsData.TB_PaymentArchive (Archivos de Pagos para Data Retention)

CREATE TABLE OperationsData.TB_PaymentArchive (
    OriginalPaymentId INT,
    MemberId INT,
    PaymentDate DATETIME,
    Amount DECIMAL(10,2),
    PaymentMethod VARCHAR(20),
    ArchiveReason VARCHAR(200)
);
GO

-- 6.6. OperationsData.TB_Maintenance (Reportes de Mantenimiento de Equipos)

CREATE TABLE OperationsData.TB_Maintenance (
    MaintenanceId INT IDENTITY(1,1) PRIMARY KEY,
    EquipmentId INT NOT NULL,
    MemberId INT NOT NULL,
    MaintenanceType VARCHAR(15) NOT NULL,
    MaintenanceSummary VARCHAR(1000) NOT NULL,
    NextMaintenanceDate DATE,
    CONSTRAINT FK_Maintenance_Equipment FOREIGN KEY (EquipmentId)
        REFERENCES GymCore.TB_Equipment (EquipmentId)
        ON DELETE CASCADE,
    CONSTRAINT FK_Maintenance_Member FOREIGN KEY (MemberId)
        REFERENCES MemberData.TB_Member (MemberId)
        ON DELETE NO ACTION
);
GO

---------------------------------------------------------------------------------------------------
-- FASE 3: IMPLEMENTACIÓN DE AUDITORÍA Y RENDIMIENTO
---------------------------------------------------------------------------------------------------

USE GymDB_Project;
GO

-- A. ESTRATEGIA DE INDEXACIÓN

-- Índice A: Ranking/Particionamiento por Sede y Edad
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IDX_GymId_BirthDate' AND object_id = OBJECT_ID('MemberData.TB_Member'))
    DROP INDEX IDX_GymId_BirthDate ON MemberData.TB_Member;
GO
CREATE NONCLUSTERED INDEX IDX_GymId_BirthDate
ON MemberData.TB_Member (GymId, BirthDate)
INCLUDE (FirstName, LastName, MemberType);
GO

-- Índice B: Particionamiento por Tipo de Miembro
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IDX_MemberType_MemberId' AND object_id = OBJECT_ID('MemberData.TB_Member'))
    DROP INDEX IDX_MemberType_MemberId ON MemberData.TB_Member;
GO
CREATE NONCLUSTERED INDEX IDX_MemberType_MemberId
ON MemberData.TB_Member (MemberType, MemberId)
INCLUDE (GymId, FirstName);
GO


-- B. TRIGGERS DE AUDITORÍA
-- -------------------------------------------------------------------

-- Triggers para las tablas de Perfiles (Membership, Trainer, Employee)

IF OBJECT_ID('dbo.TX_LOG_MEMBERSHIP','TR') IS NOT NULL DROP TRIGGER dbo.TX_LOG_MEMBERSHIP;
GO
CREATE TRIGGER TX_LOG_MEMBERSHIP ON [MemberData].[TB_Membership] AFTER INSERT, UPDATE, DELETE
AS BEGIN 
    INSERT INTO dbo.TB_AuditLog (TableName, ActionType, UserName, AuditDate)
    SELECT 'TB_Membership', CASE WHEN EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted) THEN 'UPDATE'
             WHEN EXISTS(SELECT * FROM inserted) THEN 'INSERT' ELSE 'DELETE' END, SUSER_SNAME(), GETDATE();
END;
GO

IF OBJECT_ID('dbo.TX_LOG_TRAINERPROFILE','TR') IS NOT NULL DROP TRIGGER dbo.TX_LOG_TRAINERPROFILE;
GO
CREATE TRIGGER TX_LOG_TRAINERPROFILE ON [MemberData].[TB_TrainerProfile] AFTER INSERT, UPDATE, DELETE
AS BEGIN 
    INSERT INTO dbo.TB_AuditLog (TableName, ActionType, UserName, AuditDate)
    SELECT 'TB_TrainerProfile', CASE WHEN EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted) THEN 'UPDATE'
             WHEN EXISTS(SELECT * FROM inserted) THEN 'INSERT' ELSE 'DELETE' END, SUSER_SNAME(), GETDATE();
END;
GO

IF OBJECT_ID('dbo.TX_LOG_EMPLOYEEPROFILE','TR') IS NOT NULL DROP TRIGGER dbo.TX_LOG_EMPLOYEEPROFILE;
GO
CREATE TRIGGER TX_LOG_EMPLOYEEPROFILE ON [MemberData].[TB_EmployeeProfile] AFTER INSERT, UPDATE, DELETE
AS BEGIN 
    INSERT INTO dbo.TB_AuditLog (TableName, ActionType, UserName, AuditDate)
    SELECT 'TB_EmployeeProfile', CASE WHEN EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted) THEN 'UPDATE'
             WHEN EXISTS(SELECT * FROM inserted) THEN 'INSERT' ELSE 'DELETE' END, SUSER_SNAME(), GETDATE();
END;
GO

-- Trigger para la tabla maestra de miembros

IF OBJECT_ID('dbo.TX_LOG_MEMBER','TR') IS NOT NULL DROP TRIGGER dbo.TX_LOG_MEMBER;
GO
CREATE TRIGGER TX_LOG_MEMBER ON [MemberData].[TB_Member] AFTER INSERT, UPDATE, DELETE
AS BEGIN 
    INSERT INTO dbo.TB_AuditLog (TableName, ActionType, UserName, AuditDate)
    SELECT 'TB_Member', CASE WHEN EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted) THEN 'UPDATE'
             WHEN EXISTS(SELECT * FROM inserted) THEN 'INSERT' ELSE 'DELETE' END, SUSER_SNAME(), GETDATE();
END;
GO

-- Triggers para equipos y clases

IF OBJECT_ID('dbo.TX_LOG_CLASS','TR') IS NOT NULL DROP TRIGGER dbo.TX_LOG_CLASS;
GO
CREATE TRIGGER TX_LOG_CLASS ON [GymCore].[TB_Class] AFTER INSERT, UPDATE, DELETE
AS BEGIN 
	INSERT INTO dbo.TB_AuditLog (TableName, ActionType, UserName, AuditDate)
	SELECT 'TB_Class', CASE WHEN EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted) THEN 'UPDATE'
			WHEN EXISTS(SELECT * FROM inserted) THEN 'INSERT' ELSE 'DELETE' END, SUSER_SNAME(), GETDATE();
END;
GO

IF OBJECT_ID('dbo.TX_LOG_EQUIPMENT','TR') IS NOT NULL DROP TRIGGER dbo.TX_LOG_EQUIPMENT;
GO
CREATE TRIGGER TX_LOG_EQUIPMENT ON [GymCore].[TB_Equipment] AFTER INSERT, UPDATE, DELETE
AS BEGIN 
	INSERT INTO dbo.TB_AuditLog (TableName, ActionType, UserName, AuditDate)
	SELECT 'TB_Equipment', CASE WHEN EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted) THEN 'UPDATE'
			WHEN EXISTS(SELECT * FROM inserted) THEN 'INSERT' ELSE 'DELETE' END, SUSER_SNAME(), GETDATE();
END;
GO

---------------------------------------------------------------------------------------------------
-- FASE 4: STORES PROCEDURES (Lógica de Negocio Centralizada)
---------------------------------------------------------------------------------------------------

-- SP_InsertEquipment
IF OBJECT_ID('dbo.SP_InsertEquipment','P') IS NOT NULL DROP PROCEDURE dbo.SP_InsertEquipment;
GO
CREATE PROCEDURE dbo.SP_InsertEquipment
	@ClassId INT, @EquipmentType VARCHAR(100), @Description VARCHAR(300), @LastMaintenance DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO GymCore.TB_Equipment (ClassId, EquipmentType, Description, LastMaintenance)
    VALUES (@ClassId, @EquipmentType, @Description, ISNULL(@LastMaintenance, GETDATE()));
END;
GO

-- SP_InsertMaintenance
IF OBJECT_ID('dbo.SP_InsertMaintenance','P') IS NOT NULL DROP PROCEDURE dbo.SP_InsertMaintenance;
GO
CREATE PROCEDURE dbo.SP_InsertMaintenance
	@EquipmentId INT, @MemberId INT, @MaintenanceType VARCHAR(15), @MaintenanceSummary VARCHAR(1000), @NextMaintenanceDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO OperationsData.TB_Maintenance (EquipmentId, MemberId, MaintenanceType, MaintenanceSummary, NextMaintenanceDate)
    VALUES (@EquipmentId, @MemberId, @MaintenanceType, @MaintenanceSummary, @NextMaintenanceDate);
END;
GO

-- SP_InsertPayment
IF OBJECT_ID('dbo.SP_InsertPayment','P') IS NOT NULL DROP PROCEDURE dbo.SP_InsertPayment;
GO
CREATE PROCEDURE dbo.SP_InsertPayment
	@MemberId INT, @PaymentMethod VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Amount DECIMAL(10,2) = 0;
    DECLARE @MembershipType VARCHAR(20);

    SELECT @MembershipType = MS.MembershipType
    FROM MemberData.TB_Member M
    INNER JOIN MemberData.TB_Membership MS ON M.MemberId = MS.MemberId
    WHERE M.MemberId = @MemberId AND M.MemberType = 'Member';

    IF @MembershipType IS NOT NULL
    BEGIN
        SET @Amount = CASE 
                        WHEN @MembershipType = 'Silver'   THEN 20.00
                        WHEN @MembershipType = 'Gold'     THEN 30.00
                        WHEN @MembershipType = 'Diamond'  THEN 40.00
                        ELSE 15.00
                        END;
    END

    INSERT INTO OperationsData.TB_Payment (MemberId, Amount, PaymentDescription, PaymentMethod, PaymentDate)
    VALUES (@MemberId, @Amount, 'Membership payment', @PaymentMethod, GETDATE());
END;
GO

-- SP_ArchiveMemberPayments
IF OBJECT_ID('dbo.SP_ArchiveMemberPayments','P') IS NOT NULL DROP PROCEDURE dbo.SP_ArchiveMemberPayments;
GO
CREATE PROCEDURE dbo.SP_ArchiveMemberPayments
	@MemberId INT, @Reason VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO OperationsData.TB_PaymentArchive (OriginalPaymentId, MemberId, PaymentDate, Amount, PaymentMethod, ArchiveReason)
    SELECT PaymentId, MemberId, PaymentDate, Amount, PaymentMethod, @Reason
    FROM OperationsData.TB_Payment
    WHERE MemberId = @MemberId;

    DELETE FROM OperationsData.TB_Payment
    WHERE MemberId = @MemberId;
END;
GO

-- SP_DeleteMember_ArchivePayments
IF OBJECT_ID('dbo.SP_DeleteMember_ArchivePayments','P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteMember_ArchivePayments;
GO
CREATE PROCEDURE dbo.SP_DeleteMember_ArchivePayments
	@MemberId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
     
        EXEC dbo.SP_ArchiveMemberPayments @MemberId = @MemberId, @Reason = 'Member deletion';
        
        
        DELETE FROM OperationsData.TB_Maintenance WHERE MemberId = @MemberId;
        DELETE FROM OperationsData.TB_Enrollment WHERE MemberId = @MemberId;
        
       
        DELETE FROM MemberData.TB_Membership WHERE MemberId = @MemberId;
        DELETE FROM MemberData.TB_TrainerProfile WHERE MemberId = @MemberId;
        DELETE FROM MemberData.TB_EmployeeProfile WHERE MemberId = @MemberId;
        
        
        DELETE FROM MemberData.TB_Member WHERE MemberId = @MemberId;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP_DeleteGym 
IF OBJECT_ID('dbo.SP_DeleteGym','P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteGym;
GO
CREATE PROCEDURE dbo.SP_DeleteGym @GymId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @MemberId INT;
        DECLARE @Members TABLE (MemberId INT);

        
        INSERT INTO @Members (MemberId) SELECT MemberId FROM MemberData.TB_Member WHERE GymId = @GymId;

        
        WHILE EXISTS (SELECT 1 FROM @Members)
        BEGIN
            SELECT TOP 1 @MemberId = MemberId FROM @Members;
            EXEC dbo.SP_DeleteMember_ArchivePayments @MemberId = @MemberId;
            DELETE FROM @Members WHERE MemberId = @MemberId;
        END

       
        DELETE FROM GymCore.TB_Gym WHERE GymId = @GymId;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

---------------------------------------------------------------------------------------------------
-- FASE 5: SEGURIDAD Y BACKUP 
---------------------------------------------------------------------------------------------------

-- A. IMPLEMENTACIÓN DE ROLES, USUARIOS Y PRIVILEGIOS
----------------------------------------------------

-- 1. CREACIÓN DE LOGIN
USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'GymAdminLogin')
    CREATE LOGIN GymAdminLogin WITH PASSWORD = 'P@sswOrd123!', CHECK_POLICY = ON;
GO

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'TrainerLogin')
    CREATE LOGIN TrainerLogin WITH PASSWORD = 'P@sswOrd123!', CHECK_POLICY = ON;
GO

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'ReceptionLogin')
    CREATE LOGIN ReceptionLogin WITH PASSWORD = 'P@sswOrd123!', CHECK_POLICY = ON;
GO

-- 2. CREACIÓN DE USUARIOS Y ROLES 
USE GymDB_Project;
GO

-- Creación de Usuarios (Asociación a Login)
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'GymAdminUser')
    CREATE USER GymAdminUser FOR LOGIN GymAdminLogin;
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'TrainerUser')
    CREATE USER TrainerUser FOR LOGIN TrainerLogin;
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'ReceptionUser')
    CREATE USER ReceptionUser FOR LOGIN ReceptionLogin;
GO

-- Creación de Roles Personalizados
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'Role_Admin')
    CREATE ROLE Role_Admin; 
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'Role_Trainer')
    CREATE ROLE Role_Trainer;
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'Role_Reception')
    CREATE ROLE Role_Reception;
GO

-- Asignación de Usuarios a Roles
ALTER ROLE Role_Admin ADD MEMBER GymAdminUser;
ALTER ROLE Role_Trainer ADD MEMBER TrainerUser;
ALTER ROLE Role_Reception ADD MEMBER ReceptionUser;
GO

-- Asignación de Privilegios
GRANT CONTROL ON SCHEMA::GymCore TO Role_Admin;
GRANT CONTROL ON SCHEMA::MemberData TO Role_Admin;
GRANT CONTROL ON SCHEMA::OperationsData TO Role_Admin;
GRANT EXECUTE TO Role_Admin; 

GRANT SELECT ON SCHEMA::MemberData TO Role_Trainer;
GRANT SELECT ON SCHEMA::GymCore TO Role_Trainer;
GRANT INSERT, UPDATE ON OperationsData.TB_Maintenance TO Role_Trainer;
GRANT EXECUTE ON dbo.SP_InsertMaintenance TO Role_Trainer;

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::MemberData TO Role_Reception;
GRANT SELECT, INSERT, UPDATE ON OperationsData.TB_Payment TO Role_Reception;
GRANT SELECT, INSERT, DELETE ON OperationsData.TB_Enrollment TO Role_Reception;
GRANT SELECT ON SCHEMA::GymCore TO Role_Reception;
GRANT EXECUTE ON dbo.SP_InsertPayment TO Role_Reception;
DENY DELETE ON MemberData.TB_Member TO Role_Reception; -- Borrado solo vía SP seguro
GO


-- B. ESTRATEGIA DE BACKUP
---------------------------

USE master;
GO

-- 1. Configurar modelo de recuperación FULL 
ALTER DATABASE GymDB_Project SET RECOVERY FULL;
GO

-- 2. FULL BACKUP inicial 

BACKUP DATABASE GymDB_Project
TO DISK = 'C:\Backups\GymDB_Project_FULL.bak'
WITH INIT, COMPRESSION, STATS = 10;
GO

-- 3. BACKUP DIFERENCIAL 
BACKUP DATABASE GymDB_Project
TO DISK = 'C:\Backups\GymDB_Project_DIFF.bak'
WITH DIFFERENTIAL, INIT, COMPRESSION, STATS = 10;
GO

-- 4. BACKUP DE LOG 
BACKUP LOG GymDB_Project
TO DISK = 'C:\Backups\GymDB_Project_LOG.trn'
WITH INIT, COMPRESSION, STATS = 10;
GO


--1. Restaurar el FULL Backup
RESTORE DATABASE GymDB_Project
FROM DISK = 'C:\Backups\GymDB_Project_FULL.bak'
WITH NORECOVERY, REPLACE, STATS = 10;
GO

--2. Restaurar el Diferencial
RESTORE DATABASE GymDB_Project
FROM DISK = 'C:\Backups\GymDB_Project_DIFF.bak'
WITH NORECOVERY, STATS = 10;
GO

--3. Restaurar LOG hasta un punto específico
RESTORE LOG GymDB_Project
FROM DISK = 'C:\Backups\GymDB_Project_LOG.trn'
WITH STOPAT = '2025-11-27T18:15:00', RECOVERY, STATS = 10;
GO


--------------------------------
-- FASE 6: CONSULTAS AVANZADAS 
--------------------------------

USE GymDB_Project;
GO

-- 1. TOP 5 Sedes con Mayor Ingreso Total por Pagos
SELECT TOP 5
    G.GymName AS Sede,
    COUNT(P.PaymentId) AS TotalPagos,
    SUM(P.Amount) AS IngresoTotal
FROM OperationsData.TB_Payment P
INNER JOIN MemberData.TB_Member M ON P.MemberId = M.MemberId
INNER JOIN GymCore.TB_Gym G ON M.GymId = G.GymId
GROUP BY G.GymName
ORDER BY IngresoTotal DESC;
GO

-- 2. Conteo de Miembros por Tipo de Membresía y Estado de Vigencia
SELECT
    MS.MembershipType AS TipoMembresia,
    CASE WHEN MS.IsActive = 1 THEN 'Activa' ELSE 'Expirada' END AS EstadoVigencia,
    COUNT(M.MemberId) AS CantidadMiembros
FROM MemberData.TB_Member M
INNER JOIN MemberData.TB_Membership MS ON M.MemberId = MS.MemberId
WHERE M.MemberType = 'Member'
GROUP BY MS.MembershipType, MS.IsActive
ORDER BY TipoMembresia, EstadoVigencia DESC;
GO

-- 3. Entrenadores Asignados a Clases y su Especialidad 
SELECT
    M.FirstName + ' ' + M.LastName AS NombreEntrenador,
    TP.Specialty AS Especialidad,
    COUNT(C.ClassId) AS ClasesDiferentesAsignadas,
    STRING_AGG(C.ClassName, ', ') WITHIN GROUP (ORDER BY C.ClassName) AS ListaDeClases
FROM MemberData.TB_Member M
INNER JOIN MemberData.TB_TrainerProfile TP ON M.MemberId = TP.MemberId
INNER JOIN GymCore.TB_Class C ON C.GymId = M.GymId
GROUP BY M.FirstName, M.LastName, TP.Specialty
HAVING COUNT(C.ClassId) > 0
ORDER BY ClasesDiferentesAsignadas DESC;
GO

-- 4. Equipamiento Próximo a Mantenimiento 
SELECT
    E.EquipmentType AS TipoEquipo,
    E.[Description] AS Descripcion,
    C.ClassName AS UbicacionClase,
    G.GymName AS Sede,
    E.LastMaintenance AS UltimoMantenimiento,
    DATEDIFF(DAY, E.LastMaintenance, GETDATE()) AS DiasDesdeMantenimiento
FROM GymCore.TB_Equipment E
INNER JOIN GymCore.TB_Class C ON E.ClassId = C.ClassId
INNER JOIN GymCore.TB_Gym G ON C.GymId = G.GymId
WHERE DATEDIFF(DAY, E.LastMaintenance, GETDATE()) > 90 
ORDER BY DiasDesdeMantenimiento DESC;
GO

-- 5. Listado Detallado de Empleados Administrativos 
SELECT
    M.FirstName + ' ' + M.LastName AS NombreEmpleado,
    EP.ServiceType AS TipoServicio,
    EP.StartDate AS FechaContratacion,
    G.GymName AS SedeTrabajo,
    DATEDIFF(YEAR, EP.StartDate, GETDATE()) AS AñosDeServicio
FROM MemberData.TB_Member M
INNER JOIN MemberData.TB_EmployeeProfile EP ON M.MemberId = EP.MemberId
INNER JOIN GymCore.TB_Gym G ON M.GymId = G.GymId
WHERE M.MemberType = 'Employee'
ORDER BY AñosDeServicio DESC, NombreEmpleado;
GO

-- 6. Uso de FUNCIÓN DE VENTANA (Ingreso Acumulado por Sede)
USE GymDB_Project;
GO

SELECT
    G.GymName AS Sede,
    P.PaymentDate AS FechaPago,
    P.Amount AS MontoPago,
    -- La función de ventana calcula la suma ACUMULADA.
    SUM(P.Amount) OVER (
        PARTITION BY G.GymName   -- Criterio de agrupamiento: Reinicia el cálculo por cada Gym.
        ORDER BY P.PaymentDate   -- Criterio de ordenamiento: Suma progresivamente a lo largo del tiempo.
    ) AS IngresoAcumuladoTotal
FROM OperationsData.TB_Payment P
INNER JOIN MemberData.TB_Member M ON P.MemberId = M.MemberId
INNER JOIN GymCore.TB_Gym G ON M.GymId = G.GymId
ORDER BY G.GymName, P.PaymentDate;
GO